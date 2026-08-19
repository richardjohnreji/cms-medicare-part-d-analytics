IF OBJECT_ID('silver.medicare_part_d_prescribers', 'U') IS NOT NULL
    DROP TABLE silver.medicare_part_d_prescribers;
GO

CREATE TABLE silver.medicare_part_d_prescribers
(
    Prscrbr_NPI              VARCHAR(10)   NULL,
    Prscrbr_Last_Org_Name    VARCHAR(100)  NULL,
    Prscrbr_First_Name       VARCHAR(100)  NULL,
    Prscrbr_City             VARCHAR(100)  NULL,
    Prscrbr_State_Abrvtn     VARCHAR(2)    NULL,
    Prscrbr_State_FIPS       VARCHAR(2)    NULL,
    Prscrbr_Type             VARCHAR(100)  NULL,
    Prscrbr_Type_Src         VARCHAR(100)  NULL,

    Brnd_Name                VARCHAR(255)  NULL,
    Gnrc_Name                VARCHAR(255)  NULL,

    Tot_Clms                 BIGINT        NULL,
    Tot_30day_Fills          DECIMAL(18,1) NULL,
    Tot_Day_Suply            BIGINT        NULL,
    Tot_Drug_Cst             DECIMAL(18,2) NULL,
    Tot_Benes                BIGINT        NULL,

    GE65_Sprsn_Flag          VARCHAR(1)    NULL,
    GE65_Tot_Clms            BIGINT        NULL,
    GE65_Tot_30day_Fills     DECIMAL(18,1) NULL,
    GE65_Tot_Drug_Cst        DECIMAL(18,2) NULL,
    GE65_Tot_Day_Suply       BIGINT        NULL,
    GE65_Bene_Sprsn_Flag     VARCHAR(1)    NULL,
    GE65_Tot_Benes           BIGINT        NULL,

    data_year                SMALLINT      NOT NULL,
    source_file_name         VARCHAR(255)  NOT NULL,
    ingestion_timestamp      DATETIME2     NOT NULL
);
GO
