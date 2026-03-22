-- Nettoyage et dépivotage des données INSEE
-- Transforme le format large (colonnes par genre/âge) en format long (une ligne par année/région/âge/genre)

WITH source AS (
    SELECT * FROM {{ source('raw_data', 'insee_population_enrichi') }}
),

-- Dépivotage : transformer les colonnes ensemble_*, hommes_*, femmes_* en lignes
-- Inclure IS_DROM et DROM_GROUP dans toutes les sélections
unpivoted AS (
    SELECT year, region_code, region_name, is_drom, drom_group, '0-19 ans' AS age_group_insee, 'ALL' AS gender_insee, ensemble_0_19 AS population FROM source
    UNION ALL
    SELECT year, region_code, region_name, is_drom, drom_group, '20-39 ans', 'ALL', ensemble_20_39 FROM source
    UNION ALL
    SELECT year, region_code, region_name, is_drom, drom_group, '40-59 ans', 'ALL', ensemble_40_59 FROM source
    UNION ALL
    SELECT year, region_code, region_name, is_drom, drom_group, '60-74 ans', 'ALL', ensemble_60_74 FROM source
    UNION ALL
    SELECT year, region_code, region_name, is_drom, drom_group, '75+ ans', 'ALL', ensemble_75_plus FROM source
    UNION ALL
    SELECT year, region_code, region_name, is_drom, drom_group, '0-19 ans', 'M', hommes_0_19 FROM source
    UNION ALL
    SELECT year, region_code, region_name, is_drom, drom_group, '20-39 ans', 'M', hommes_20_39 FROM source
    UNION ALL
    SELECT year, region_code, region_name, is_drom, drom_group, '40-59 ans', 'M', hommes_40_59 FROM source
    UNION ALL
    SELECT year, region_code, region_name, is_drom, drom_group, '60-74 ans', 'M', hommes_60_74 FROM source
    UNION ALL
    SELECT year, region_code, region_name, is_drom, drom_group, '75+ ans', 'M', hommes_75_plus FROM source
    UNION ALL
    SELECT year, region_code, region_name, is_drom, drom_group, '0-19 ans', 'F', femmes_0_19 FROM source
    UNION ALL
    SELECT year, region_code, region_name, is_drom, drom_group, '20-39 ans', 'F', femmes_20_39 FROM source
    UNION ALL
    SELECT year, region_code, region_name, is_drom, drom_group, '40-59 ans', 'F', femmes_40_59 FROM source
    UNION ALL
    SELECT year, region_code, region_name, is_drom, drom_group, '60-74 ans', 'F', femmes_60_74 FROM source
    UNION ALL
    SELECT year, region_code, region_name, is_drom, drom_group, '75+ ans', 'F', femmes_75_plus FROM source
),

cleaned AS (
    SELECT
        TRY_TO_NUMBER(year) AS year,
        region_code,
        region_name,
        CASE
            WHEN is_drom = 1 THEN 'DROM'
            WHEN TRIM(region_name) IN ('Auvergne-Rhone-Alpes', 'Auvergne-Rhône-Alpes')
                THEN 'Auvergne-Rhône-Alpes'
            WHEN TRIM(region_name) IN ('Bourgogne-Franche-Comte', 'Bourgogne-Franche-Comté')
                THEN 'Bourgogne-Franche-Comté'
            WHEN region_name = 'Centre-Val de Loire' THEN 'Centre-Val-de-Loire'
            WHEN TRIM(region_name) IN ('Grand-Est', 'Grand Est')
                THEN 'Grand Est'
            WHEN TRIM(region_name) IN ('Ile-de-France', 'Île-de-France')
                THEN 'Île-de-France'
            WHEN TRIM(region_name) IN ('Pays-de-la-Loire', 'Pays de la Loire')
                THEN 'Pays de la Loire'
            WHEN TRIM(region_name) IN ('Provence-Alpes-Cote-d-Azur', 'Provence-Alpes-Côte d''Azur')
                THEN 'Provence-Alpes-Côte d''Azur'
            ELSE NULLIF(TRIM(region_name), '')
        END AS region_name_standardized,
        CASE
            WHEN age_group_insee IN ('60-74 ans', '75+ ans') THEN '60+ ans'
            ELSE age_group_insee
        END AS age_group_insee,
        gender_insee,
        TRY_TO_NUMBER(population) AS population,
        is_drom,
        drom_group
    FROM unpivoted
    WHERE population IS NOT NULL
)

SELECT *
FROM cleaned
WHERE year IN (2022, 2023, 2024, 2025)
  AND region_name_standardized IS NOT NULL
    AND age_group_insee IN ('0-19 ans', '20-39 ans', '40-59 ans', '60+ ans')
  AND gender_insee IN ('M', 'F', 'ALL')
  AND population IS NOT NULL
