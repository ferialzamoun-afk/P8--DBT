-- 1) Se placer dans le bon contexte
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE P8_OPENCLASSROOMS;
USE SCHEMA RAW_DATA;

-- 2) Creer le format CSV
CREATE OR REPLACE FILE FORMAT FF_CSV_STD
  TYPE = CSV
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  TRIM_SPACE = TRUE
  NULL_IF = ('', 'NULL');

-- 3) Creer une table de landing
CREATE OR REPLACE TABLE GEO_REF_DEPARTMENT_REGION (
  DEPARTMENT_CODE STRING,
  DEPARTMENT_NAME STRING,
  REGION_CODE STRING,
  REGION_NAME STRING,
  IS_DROM NUMBER(1,0),
  DROM_GROUP STRING
);

-- 4) Option A: Import via stage interne Snowflake
--   4.1) Creer un stage
CREATE OR REPLACE STAGE STG_GEO_REF
  FILE_FORMAT = FF_CSV_STD;

--   4.2) Dans Snowsight, ouvrir le stage STG_GEO_REF et charger
--        le fichier geo_ref_template_for_snowflake.csv
--        (ou votre fichier complet nettoye)

--   4.3) Charger depuis stage vers la table
COPY INTO GEO_REF_DEPARTMENT_REGION
FROM @STG_GEO_REF/geo_ref_template_for_snowflake.csv
FILE_FORMAT = (FORMAT_NAME = FF_CSV_STD)
ON_ERROR = CONTINUE;

-- 5) Controle rapide apres chargement
SELECT COUNT(*) AS nb_rows
FROM GEO_REF_DEPARTMENT_REGION;

SELECT *
FROM GEO_REF_DEPARTMENT_REGION
ORDER BY DEPARTMENT_CODE
LIMIT 20;

-- 6) Detection de problemes classiques
-- doublons code departement
SELECT DEPARTMENT_CODE, COUNT(*) AS c
FROM GEO_REF_DEPARTMENT_REGION
GROUP BY DEPARTMENT_CODE
HAVING COUNT(*) > 1;

-- valeurs nulles sur cles
SELECT *
FROM GEO_REF_DEPARTMENT_REGION
WHERE DEPARTMENT_CODE IS NULL
   OR REGION_NAME IS NULL;
