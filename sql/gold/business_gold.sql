/* ============================================================
   GOLD LAYER - POWER BI MEASURE BASELINE
   Healthcare Analytics Project
   CMS Medicare Part D Prescribers

   Purpose:
   Establish the baseline values for the measures that will
   actually be used in the Power BI dashboard.

   IMPORTANT:
   This is NOT a full Gold-layer validation.
   It is a business-measure validation.

   Fact grain:
   Prescriber NPI + Brand Name + Generic Name + Data Year

   Source:
   gold.vw_fact_prescription
   gold.vw_dim_provider
   gold.vw_dim_drug
   ============================================================ */


/* ============================================================
   1. CORE FACT MEASURES
   ============================================================

   One aggregation pass calculates the expensive numeric
   measures together.

   This avoids repeatedly scanning the 28M-row fact table.
   ============================================================ */

SELECT
    COUNT_BIG(*) AS fact_rows,

    SUM(Tot_Clms) AS total_claims,

    SUM(Tot_30day_Fills) AS total_30day_fills,

    SUM(Tot_Day_Suply) AS total_day_supply,

    SUM(Tot_Drug_Cst) AS total_drug_cost,

    COUNT(DISTINCT Prscrbr_NPI) AS distinct_prescribers,

    COUNT(DISTINCT DrugKey) AS distinct_drugs

FROM gold.vw_fact_prescribing;


/* ============================================================
   2. DERIVED BUSINESS MEASURES
   ============================================================

   These measures are calculated from the same baseline totals.

   NULLIF prevents division-by-zero errors.
   ============================================================ */

SELECT
    SUM(Tot_Drug_Cst)
        / NULLIF(SUM(Tot_Clms), 0)
        AS avg_cost_per_claim,

    SUM(Tot_Drug_Cst)
        / NULLIF(SUM(Tot_30day_Fills), 0)
        AS avg_cost_per_30day_fill,

    SUM(Tot_Clms)
        / NULLIF(
            COUNT(DISTINCT Prscrbr_NPI),
            0
        )
        AS avg_claims_per_prescriber

FROM gold.vw_fact_prescribing;


/* ============================================================
   3. BENEFICIARY MEASURE
   ============================================================

   Tot_Benes can contain NULL because CMS suppresses beneficiary
   counts from 1-10.

   Therefore:

       SUM(Tot_Benes)

   intentionally ignores suppressed NULL values.

   This is NOT equivalent to treating NULL as zero.
   The result should therefore be interpreted as a
   lower-bound / published-value total rather than the
   complete underlying beneficiary population.
   ============================================================ */

SELECT
    SUM(Tot_Benes) AS published_total_beneficiaries,

    COUNT(*) AS fact_rows,

    COUNT(Tot_Benes) AS rows_with_reported_beneficiaries,

    COUNT(*) - COUNT(Tot_Benes)
        AS rows_with_suppressed_beneficiaries

FROM gold.vw_fact_prescribing;


/* ============================================================
   4. OPTIONAL: ONE-ROW EXECUTIVE BASELINE
   ============================================================

   This is the version I recommend saving as the final
   validation result for comparison with Power BI.
   ============================================================ */

SELECT
    COUNT_BIG(*) AS fact_rows,

    SUM(Tot_Clms) AS total_claims,

    SUM(Tot_30day_Fills) AS total_30day_fills,

    SUM(Tot_Day_Suply) AS total_day_supply,

    SUM(Tot_Drug_Cst) AS total_drug_cost,

    SUM(Tot_Benes) AS published_total_beneficiaries,

    COUNT(DISTINCT Prscrbr_NPI) AS distinct_prescribers,

    COUNT(DISTINCT DrugKey) AS distinct_drugs,

    SUM(Tot_Drug_Cst)
        / NULLIF(SUM(Tot_Clms), 0)
        AS avg_cost_per_claim,

    SUM(Tot_Drug_Cst)
        / NULLIF(SUM(Tot_30day_Fills), 0)
        AS avg_cost_per_30day_fill,

    SUM(Tot_Clms)
        / NULLIF(COUNT(DISTINCT Prscrbr_NPI), 0)
        AS avg_claims_per_prescriber

FROM gold.vw_fact_prescribing;

