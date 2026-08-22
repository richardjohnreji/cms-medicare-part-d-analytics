/* ============================================================
   HEALTHCARE ANALYTICS PROJECT
   CMS MEDICARE PART D PRESCRIBERS

   GOLD LAYER - DIMENSIONAL MODEL

   Source:
       silver.medicare_part_d_prescribers

   Fact Grain:
       One row = One Provider + One Drug + One Reporting Year

   Gold Star Schema:

                    dim_provider
                         │
                         │ 1
                         │
                         │ *
                         ▼
                  fact_prescribing
                    ▲           ▲
                    │           │
                   *│           │*
                    │           │
                    1           1
               dim_drug      dim_date

   ============================================================ */


USE HealthcareDW;
GO


/* ============================================================
   CREATE GOLD SCHEMA
   ============================================================ */

/* ============================================================
   1. PROVIDER DIMENSION

   Business Question:
       Who is prescribing the drug?

   Grain:
       One row = One unique Provider / NPI

   Relationship:
       gold.vw_dim_provider[Prscrbr_NPI]
               1
               │
               │
               *
       gold.vw_fact_prescribing[Prscrbr_NPI]

   Note:
       Validation confirmed that Prscrbr_NPI is unique.
   ============================================================ */

CREATE OR ALTER VIEW gold.vw_dim_provider
AS
SELECT DISTINCT

    /* Provider business key */
    Prscrbr_NPI,

    /* Provider name */
    Prscrbr_Last_Org_Name,
    Prscrbr_First_Name,

    /* Provider location */
    Prscrbr_City,
    Prscrbr_State_Abrvtn,
    Prscrbr_State_FIPS,

    /* Provider specialty */
    Prscrbr_Type,

    /* Source used to determine provider specialty */
    Prscrbr_Type_Src

FROM silver.medicare_part_d_prescribers;
GO


/* ============================================================
   2. DRUG DIMENSION

   Business Question:
       What drug was prescribed?

   Grain:
       One row = One unique Brand + Generic Name combination

   DrugKey:
       Created using Brand Name + Generic Name.

   Validation confirmed that the Brand + Generic combination
   is unique.

   Relationship:
       gold.vw_dim_drug[DrugKey]
               1
               │
               │
               *
       gold.vw_fact_prescribing[DrugKey]
   ============================================================ */

CREATE OR ALTER VIEW gold.vw_dim_drug
AS
SELECT DISTINCT

    /* Unique business key for each drug combination */
    CONCAT_WS(
        '|',
        ISNULL(Brnd_Name, ''),
        ISNULL(Gnrc_Name, '')
    ) AS DrugKey,

    /* Drug descriptive attributes */
    Brnd_Name,
    Gnrc_Name

FROM silver.medicare_part_d_prescribers;
GO


/* ============================================================
   3. REPORTING YEAR DIMENSION

   Business Question:
       When was the prescribing activity reported?

   Grain:
       One row = One reporting year

   Current dataset:
       2024

   This dimension is designed to support future years when
   additional CMS datasets are added.

   Relationship:
       gold.vw_dim_date[DateKey]
               1
               │
               │
               *
       gold.vw_fact_prescribing[DateKey]
   ============================================================ */

CREATE OR ALTER VIEW gold.vw_dim_date
AS
SELECT DISTINCT

    /* Business key for reporting year */
    data_year AS DateKey,

    /* User-friendly reporting year */
    data_year AS ReportingYear

FROM silver.medicare_part_d_prescribers;
GO


/* ============================================================
   4. PRESCRIBING FACT TABLE

   Business Question:
       How much prescribing activity occurred?

   Grain:
       One row =
           One Provider
           + One Drug
           + One Reporting Year

   Dimension Keys:
       Prscrbr_NPI  -> Provider Dimension
       DrugKey      -> Drug Dimension
       DateKey      -> Date Dimension

   Measures:
       Claims
       30-Day Fills
       Day Supply
       Drug Cost
       Beneficiary Counts
       Age 65+ Measures

   IMPORTANT:
       NULL values in suppressed CMS measures are intentionally
       preserved.

       NULL does NOT automatically mean zero.

   ============================================================ */

CREATE OR ALTER VIEW gold.vw_fact_prescribing
AS
SELECT

    /* ========================================================
       DIMENSION KEYS
       ======================================================== */

    /* Links to Provider Dimension */
    Prscrbr_NPI,

    /* Links to Drug Dimension */
    CONCAT_WS(
        '|',
        ISNULL(Brnd_Name, ''),
        ISNULL(Gnrc_Name, '')
    ) AS DrugKey,

    /* Links to Reporting Year Dimension */
    data_year AS DateKey,


    /* ========================================================
       CORE PRESCRIBING / UTILIZATION MEASURES
       ======================================================== */

    /* Total Medicare Part D claims, including refills */
    Tot_Clms,

    /* Total standardized 30-day fills */
    Tot_30day_Fills,

    /* Total number of days supplied */
    Tot_Day_Suply,


    /* ========================================================
       FINANCIAL MEASURE
       ======================================================== */

    /* Aggregate drug cost */
    Tot_Drug_Cst,


    /* ========================================================
       BENEFICIARY MEASURE
       ======================================================== */

    /*
       Total unique beneficiaries.

       NULL values are preserved because CMS suppresses
       certain beneficiary counts for privacy reasons.
    */
    Tot_Benes,


    /* ========================================================
       AGE 65+ SUPPRESSION FLAG
       ======================================================== */

    GE65_Sprsn_Flag,


    /* ========================================================
       AGE 65+ UTILIZATION MEASURES
       ======================================================== */

    /* Claims for beneficiaries age 65 and older */
    GE65_Tot_Clms,

    /* Standardized 30-day fills for age 65+ */
    GE65_Tot_30day_Fills,

    /* Aggregate drug cost for age 65+ */
    GE65_Tot_Drug_Cst,

    /* Total days supplied for age 65+ */
    GE65_Tot_Day_Suply,


    /* ========================================================
       AGE 65+ BENEFICIARY SUPPRESSION
       ======================================================== */

    GE65_Bene_Sprsn_Flag,


    /* ========================================================
       AGE 65+ BENEFICIARY MEASURE
       ======================================================== */

    /*
       Total beneficiaries age 65 and older.

       NULL values are preserved because suppressed values
       should not be interpreted as zero.
    */
    GE65_Tot_Benes

FROM silver.medicare_part_d_prescribers;
GO