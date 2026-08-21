import pandas as pd
from pathlib import Path

CSV_PATH = Path(
    r"YOUR FILE PATH"
)

CHUNK_SIZE = 100_000

print("=" * 75)
print("CMS MEDICARE PART D — FULL SOURCE SYMBOL AUDIT")
print("=" * 75)

star_counts = {}
hash_counts = {}
blank_counts = {}
nonblank_counts = {}

total_rows = 0
chunk_number = 0

for df in pd.read_csv(
    CSV_PATH,
    chunksize=CHUNK_SIZE,
    dtype="string",
    keep_default_na=False,
):
    chunk_number += 1
    total_rows += len(df)

    for col in df.columns:

        values = df[col]

        blank_counts[col] = (
            blank_counts.get(col, 0)
            + (values == "").sum()
        )

        star_counts[col] = (
            star_counts.get(col, 0)
            + (values == "*").sum()
        )

        hash_counts[col] = (
            hash_counts.get(col, 0)
            + (values == "#").sum()
        )

        nonblank_counts[col] = (
            nonblank_counts.get(col, 0)
            + (values != "").sum()
        )

    if chunk_number % 10 == 0:
        print(
            f"Processed chunk {chunk_number} | "
            f"Rows processed: {total_rows:,}"
        )


print("\n" + "=" * 75)
print("AUDIT RESULTS")
print("=" * 75)

print(f"\nTotal rows scanned: {total_rows:,}")
print(f"Columns scanned:    {len(blank_counts)}")


print("\nBLANK VALUES")
print("-" * 75)

for col in blank_counts:

    count = blank_counts[col]

    if count > 0:

        pct = count / total_rows * 100

        print(
            f"{col:35} "
            f"{count:>12,} "
            f"({pct:>7.2f}%)"
        )


print("\nASTERISK (*) VALUES")
print("-" * 75)

found_star = False

for col in star_counts:

    count = star_counts[col]

    if count > 0:

        found_star = True

        pct = count / total_rows * 100

        print(
            f"{col:35} "
            f"{count:>12,} "
            f"({pct:>7.2f}%)"
        )

if not found_star:
    print("No '*' values found.")


print("\nHASH (#) VALUES")
print("-" * 75)

found_hash = False

for col in hash_counts:

    count = hash_counts[col]

    if count > 0:

        found_hash = True

        pct = count / total_rows * 100

        print(
            f"{col:35} "
            f"{count:>12,} "
            f"({pct:>7.2f}%)"
        )

if not found_hash:
    print("No '#' values found.")


print("\n" + "=" * 75)
print("AUDIT COMPLETE")
print("=" * 75)
