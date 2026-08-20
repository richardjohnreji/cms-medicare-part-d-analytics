import pandas as pd
import pyodbc
import time
from decimal import Decimal
from pathlib import Path
from datetime import datetime


# ============================================================
# CONFIGURATION
# ============================================================

CSV_PATH = Path(
    r"YOUR FILE PATH"
)

SERVER = r"YOUR SERVER NAME"
DATABASE = "HealthcareDW"

TABLE = "bronze.medicare_part_d_prescribers"

CHUNK_SIZE = 100_000

DATA_YEAR = 2024

SOURCE_FILE = CSV_PATH.name


CONNECTION_STRING = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    f"SERVER={SERVER};"
    f"DATABASE={DATABASE};"
    "Trusted_Connection=yes;"
    "TrustServerCertificate=yes;"
)


# ============================================================
# SOURCE COLUMNS
# ============================================================

SOURCE_COLUMNS = [
    "Prscrbr_NPI",
    "Prscrbr_Last_Org_Name",
    "Prscrbr_First_Name",
    "Prscrbr_City",
    "Prscrbr_State_Abrvtn",
    "Prscrbr_State_FIPS",
    "Prscrbr_Type",
    "Prscrbr_Type_Src",
    "Brnd_Name",
    "Gnrc_Name",
    "Tot_Clms",
    "Tot_30day_Fills",
    "Tot_Day_Suply",
    "Tot_Drug_Cst",
    "Tot_Benes",
    "GE65_Sprsn_Flag",
    "GE65_Tot_Clms",
    "GE65_Tot_30day_Fills",
    "GE65_Tot_Drug_Cst",
    "GE65_Tot_Day_Suply",
    "GE65_Bene_Sprsn_Flag",
    "GE65_Tot_Benes",
]


# ============================================================
# DECIMAL COLUMNS
# ============================================================

DECIMAL_COLUMNS = [
    "Tot_30day_Fills",
    "Tot_Drug_Cst",
    "GE65_Tot_30day_Fills",
    "GE65_Tot_Drug_Cst",
]


# ============================================================
# PANDAS STRING COLUMNS
# ============================================================

STRING_COLUMNS = {
    "Prscrbr_NPI": "string",
    "Prscrbr_Last_Org_Name": "string",
    "Prscrbr_First_Name": "string",
    "Prscrbr_City": "string",
    "Prscrbr_State_Abrvtn": "string",
    "Prscrbr_State_FIPS": "string",
    "Prscrbr_Type": "string",
    "Prscrbr_Type_Src": "string",
    "Brnd_Name": "string",
    "Gnrc_Name": "string",
    "GE65_Sprsn_Flag": "string",
    "GE65_Bene_Sprsn_Flag": "string",
}


# ============================================================
# HELPER — CLEAN PANDAS VALUES
# ============================================================

def prepare_dataframe(df):

    # Convert pandas extension types to ordinary Python objects.
    df = df.astype(object)

    # Convert pandas NA/NaN to Python None.
    df = df.where(pd.notna(df), None)

    # Convert decimal fields to Decimal.
    for col in DECIMAL_COLUMNS:

        df[col] = df[col].apply(
            lambda x:
                Decimal(str(x))
                if x is not None
                else None
        )

    return df


# ============================================================
# HELPER — BUILD SQL
# ============================================================

def build_insert_sql():

    columns = SOURCE_COLUMNS + [
        "data_year",
        "source_file_name",
        "ingestion_timestamp",
    ]

    column_list = ", ".join(
        f"[{column}]"
        for column in columns
    )

    placeholders = ", ".join(
        "?"
        for _ in columns
    )

    sql = f"""
    INSERT INTO {TABLE}
    (
        {column_list}
    )
    VALUES
    (
        {placeholders}
    )
    """

    return sql, columns


# ============================================================
# START
# ============================================================

print("=" * 75)
print("CMS MEDICARE PART D — PRODUCTION BRONZE LOAD")
print("=" * 75)

print(f"Source:      {CSV_PATH}")
print(f"Database:    {DATABASE}")
print(f"Table:       {TABLE}")
print(f"Chunk size:  {CHUNK_SIZE:,}")
print()


# ============================================================
# FILE CHECK
# ============================================================

if not CSV_PATH.exists():

    raise FileNotFoundError(
        f"Source CSV not found: {CSV_PATH}"
    )


file_size_gb = CSV_PATH.stat().st_size / (1024 ** 3)

print(
    f"Source file size: {file_size_gb:.2f} GB"
)


# ============================================================
# DATABASE CONNECTION
# ============================================================

print("\nConnecting to SQL Server...")

conn = pyodbc.connect(CONNECTION_STRING)

cursor = conn.cursor()

cursor.fast_executemany = True


# ============================================================
# DUPLICATE PROTECTION
# ============================================================

print("Checking for existing load...")

cursor.execute(
    f"""
    SELECT COUNT(*)
    FROM {TABLE}
    WHERE data_year = ?
      AND source_file_name = ?
    """,
    DATA_YEAR,
    SOURCE_FILE,
)

existing_rows = cursor.fetchone()[0]

print(
    f"Existing rows for this source: {existing_rows:,}"
)

if existing_rows > 0:

    cursor.close()
    conn.close()

    raise RuntimeError(
        "\n"
        "LOAD ABORTED.\n"
        f"Bronze already contains {existing_rows:,} rows "
        f"for {SOURCE_FILE}.\n\n"
        "This protection prevents accidental duplicate loading.\n"
        "Inspect the existing load before continuing."
    )


# ============================================================
# BUILD INSERT STATEMENT
# ============================================================

insert_sql, insert_columns = build_insert_sql()


# ============================================================
# LOAD CSV IN CHUNKS
# ============================================================

print("\nStarting production load...")
print("Do NOT start another copy of this script.")
print()

overall_start = time.perf_counter()

total_rows = 0

chunk_number = 0

total_chunks = None


try:

    reader = pd.read_csv(
        CSV_PATH,
        chunksize=CHUNK_SIZE,
        dtype=STRING_COLUMNS,
    )

    for df in reader:

        chunk_number += 1

        chunk_start = time.perf_counter()

        rows_in_chunk = len(df)

        print(
            f"Chunk {chunk_number} | "
            f"Rows: {rows_in_chunk:,}"
        )

        # ----------------------------------------------------
        # Add metadata
        # ----------------------------------------------------

        ingestion_timestamp = datetime.now()

        df["data_year"] = DATA_YEAR

        df["source_file_name"] = SOURCE_FILE

        df["ingestion_timestamp"] = ingestion_timestamp

        # ----------------------------------------------------
        # Type preparation
        # ----------------------------------------------------

        df = prepare_dataframe(df)

        # ----------------------------------------------------
        # Convert DataFrame → tuples
        # ----------------------------------------------------

        rows = [
            tuple(
                row[column]
                for column in insert_columns
            )
            for _, row in df.iterrows()
        ]

        # ----------------------------------------------------
        # Insert current chunk
        # ----------------------------------------------------

        try:

            cursor.executemany(
                insert_sql,
                rows
            )

            conn.commit()

        except Exception:

            conn.rollback()

            raise

        # ----------------------------------------------------
        # Update counters
        # ----------------------------------------------------

        total_rows += rows_in_chunk

        chunk_elapsed = (
            time.perf_counter()
            - chunk_start
        )

        overall_elapsed = (
            time.perf_counter()
            - overall_start
        )

        throughput = (
            total_rows / overall_elapsed
            if overall_elapsed > 0
            else 0
        )

        print(
            f"Chunk {chunk_number} committed | "
            f"Total rows: {total_rows:,} | "
            f"Chunk time: {chunk_elapsed:.2f}s | "
            f"Overall throughput: "
            f"{throughput:,.0f} rows/sec"
        )

        print()


except KeyboardInterrupt:

    print("\n")
    print("=" * 75)
    print("LOAD INTERRUPTED")
    print("=" * 75)

    print(
        f"Committed rows before interruption: "
        f"{total_rows:,}"
    )

    print(
        "The current uncommitted transaction "
        "has been rolled back."
    )

    conn.rollback()

    raise


except Exception as e:

    print("\n")
    print("=" * 75)
    print("LOAD FAILED")
    print("=" * 75)

    print(
        f"Committed rows before failure: "
        f"{total_rows:,}"
    )

    print(
        f"Error: {e}"
    )

    conn.rollback()

    raise


finally:

    cursor.close()
    conn.close()


# ============================================================
# LOAD COMPLETE
# ============================================================

overall_elapsed = (
    time.perf_counter()
    - overall_start
)

print()
print("=" * 75)
print("PRODUCTION LOAD COMPLETE")
print("=" * 75)

print(
    f"Chunks processed:    {chunk_number:,}"
)

print(
    f"Rows loaded:         {total_rows:,}"
)

print(
    f"Elapsed time:        "
    f"{overall_elapsed / 60:.2f} minutes"
)

print(
    f"Average throughput:  "
    f"{total_rows / overall_elapsed:,.0f} rows/sec"
)

print()
print("Next step: run final Bronze validation.")
