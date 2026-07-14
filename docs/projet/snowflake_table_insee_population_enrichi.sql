-- Creation et chargement de la table RAW_DATA.INSEE_POPULATION_ENRICHI
-- Mapping explicite des 25 colonnes pour garantir le remplissage de IS_DROM et DROM_GROUP

USE DATABASE P8_OPENCLASSROOMS;
USE SCHEMA RAW_DATA;

CREATE OR REPLACE TABLE RAW_DATA.INSEE_POPULATION_ENRICHI (
	year NUMBER,
	department_code VARCHAR,
	department_name VARCHAR,
	ensemble_0_19 NUMBER,
	ensemble_20_39 NUMBER,
	ensemble_40_59 NUMBER,
	ensemble_60_74 NUMBER,
	ensemble_75_plus NUMBER,
	ensemble_total NUMBER,
	hommes_0_19 NUMBER,
	hommes_20_39 NUMBER,
	hommes_40_59 NUMBER,
	hommes_60_74 NUMBER,
	hommes_75_plus NUMBER,
	hommes_total NUMBER,
	femmes_0_19 NUMBER,
	femmes_20_39 NUMBER,
	femmes_40_59 NUMBER,
	femmes_60_74 NUMBER,
	femmes_75_plus NUMBER,
	femmes_total NUMBER,
	region_code VARCHAR,
	region_name VARCHAR,
	is_drom NUMBER(1,0),
	drom_group VARCHAR
);

CREATE OR REPLACE FILE FORMAT RAW_DATA.FF_INSEE_POPULATION_ENRICHI
	TYPE = CSV
	FIELD_DELIMITER = ','
	SKIP_HEADER = 1
	FIELD_OPTIONALLY_ENCLOSED_BY = '"'
	TRIM_SPACE = TRUE
	NULL_IF = ('NULL');

-- Adaptez le stage/nom de fichier si besoin.
-- Exemple attendu: @RAW_DATA.STG_INSEE_POPULATION_ENRICHI/insee_population_enrichi.csv
COPY INTO RAW_DATA.INSEE_POPULATION_ENRICHI (
	year,
	department_code,
	department_name,
	ensemble_0_19,
	ensemble_20_39,
	ensemble_40_59,
	ensemble_60_74,
	ensemble_75_plus,
	ensemble_total,
	hommes_0_19,
	hommes_20_39,
	hommes_40_59,
	hommes_60_74,
	hommes_75_plus,
	hommes_total,
	femmes_0_19,
	femmes_20_39,
	femmes_40_59,
	femmes_60_74,
	femmes_75_plus,
	femmes_total,
	region_code,
	region_name,
	is_drom,
	drom_group
)
FROM (
	SELECT
		$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,
		$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,
		$21,$22,$23,$24,$25
	FROM @RAW_DATA.STG_INSEE_POPULATION_ENRICHI/insee_population_enrichi.csv
)
FILE_FORMAT = (FORMAT_NAME = RAW_DATA.FF_INSEE_POPULATION_ENRICHI)
ON_ERROR = ABORT_STATEMENT;

-- Controles rapides apres chargement
SELECT is_drom, COUNT(*) AS nb_rows
FROM RAW_DATA.INSEE_POPULATION_ENRICHI
GROUP BY is_drom
ORDER BY is_drom;

SELECT department_code, department_name, region_name, is_drom, drom_group
FROM RAW_DATA.INSEE_POPULATION_ENRICHI
WHERE department_code IN ('971', '972', '973', '974', '976')
ORDER BY department_code;