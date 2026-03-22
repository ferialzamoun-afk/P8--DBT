-- Nettoyage et harmonisation des données étudiants
-- Transformations:
--   1. Harmoniser les régions (DOM → DROM, accents/tirets)
--   2. Normaliser les tranches d'âge (30 à 34 ans → 30-34 ans)
--   3. Agréger "60 ans ou plus"

WITH source AS (
    SELECT * FROM {{ source('raw_data', 'etudiants') }}
),

normalized AS (
    SELECT
        TRIM(USER_ID) AS USER_ID,
        TRIM(PATH_CATEGORY_NAME) AS PATH_CATEGORY_NAME,
        
        -- Harmonisation des tranches d'âge
        -- Mapper "30 à 34 ans" vers "30-34 ans" et standardiser le format
        CASE
            WHEN TRIM(AGE_GROUP) = '30 à 34 ans' THEN '30-34 ans'
            WHEN TRIM(AGE_GROUP) LIKE '60%' THEN '60 ans ou plus'
            ELSE TRIM(AGE_GROUP)
        END AS AGE_GROUP,
        
        -- Gestion des valeurs manquantes GENDER
        CASE
            WHEN GENDER IS NULL OR TRIM(GENDER) = '' THEN 'Non renseigné'
            WHEN UPPER(TRIM(GENDER)) IN ('H', 'HOMME', 'M') THEN 'M'
            WHEN UPPER(TRIM(GENDER)) IN ('F', 'FEMME') THEN 'F'
            WHEN TRIM(GENDER) = 'Non renseigné' THEN 'Non renseigné'
            ELSE 'Non renseigné'
        END AS GENDER,
        
        -- Harmonisation des régions vers un libellé canonique unique
        CASE
            WHEN REGEXP_REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(TRIM(REGION)), 'À', 'A'), 'Â', 'A'), 'Ä', 'A'), 'Ç', 'C'), 'É', 'E'), 'È', 'E'), 'Ê', 'E'), 'Ë', 'E'), 'Î', 'I'), 'Ï', 'I'), 'Ô', 'O'), 'Ö', 'O'), 'Ù', 'U'), 'Û', 'U'), 'Ü', 'U'), 'Œ', 'OE'),
                '[^A-Z0-9]', ''
            ) IN ('GUADELOUPE', 'MARTINIQUE', 'REUNION', 'LAREUNION', 'GUYANE', 'DOM', 'DROM')
                THEN 'DROM'
            WHEN REGEXP_REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(TRIM(REGION)), 'À', 'A'), 'Â', 'A'), 'Ä', 'A'), 'Ç', 'C'), 'É', 'E'), 'È', 'E'), 'Ê', 'E'), 'Ë', 'E'), 'Î', 'I'), 'Ï', 'I'), 'Ô', 'O'), 'Ö', 'O'), 'Ù', 'U'), 'Û', 'U'), 'Ü', 'U'), 'Œ', 'OE'),
                '[^A-Z0-9]', ''
            ) = 'AUVERGNERHONEALPES'
                THEN 'Auvergne-Rhône-Alpes'
            WHEN REGEXP_REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(TRIM(REGION)), 'À', 'A'), 'Â', 'A'), 'Ä', 'A'), 'Ç', 'C'), 'É', 'E'), 'È', 'E'), 'Ê', 'E'), 'Ë', 'E'), 'Î', 'I'), 'Ï', 'I'), 'Ô', 'O'), 'Ö', 'O'), 'Ù', 'U'), 'Û', 'U'), 'Ü', 'U'), 'Œ', 'OE'),
                '[^A-Z0-9]', ''
            ) = 'BOURGOGNEFRANCHECOMTE'
                THEN 'Bourgogne-Franche-Comté'
            WHEN REGEXP_REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(TRIM(REGION)), 'À', 'A'), 'Â', 'A'), 'Ä', 'A'), 'Ç', 'C'), 'É', 'E'), 'È', 'E'), 'Ê', 'E'), 'Ë', 'E'), 'Î', 'I'), 'Ï', 'I'), 'Ô', 'O'), 'Ö', 'O'), 'Ù', 'U'), 'Û', 'U'), 'Ü', 'U'), 'Œ', 'OE'),
                '[^A-Z0-9]', ''
            ) = 'CENTREVALDELOIRE'
                THEN 'Centre-Val-de-Loire'
            WHEN REGEXP_REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(TRIM(REGION)), 'À', 'A'), 'Â', 'A'), 'Ä', 'A'), 'Ç', 'C'), 'É', 'E'), 'È', 'E'), 'Ê', 'E'), 'Ë', 'E'), 'Î', 'I'), 'Ï', 'I'), 'Ô', 'O'), 'Ö', 'O'), 'Ù', 'U'), 'Û', 'U'), 'Ü', 'U'), 'Œ', 'OE'),
                '[^A-Z0-9]', ''
            ) = 'GRANDEST'
                THEN 'Grand Est'
            WHEN REGEXP_REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(TRIM(REGION)), 'À', 'A'), 'Â', 'A'), 'Ä', 'A'), 'Ç', 'C'), 'É', 'E'), 'È', 'E'), 'Ê', 'E'), 'Ë', 'E'), 'Î', 'I'), 'Ï', 'I'), 'Ô', 'O'), 'Ö', 'O'), 'Ù', 'U'), 'Û', 'U'), 'Ü', 'U'), 'Œ', 'OE'),
                '[^A-Z0-9]', ''
            ) = 'ILEDEFRANCE'
                THEN 'Île-de-France'
            WHEN REGEXP_REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(TRIM(REGION)), 'À', 'A'), 'Â', 'A'), 'Ä', 'A'), 'Ç', 'C'), 'É', 'E'), 'È', 'E'), 'Ê', 'E'), 'Ë', 'E'), 'Î', 'I'), 'Ï', 'I'), 'Ô', 'O'), 'Ö', 'O'), 'Ù', 'U'), 'Û', 'U'), 'Ü', 'U'), 'Œ', 'OE'),
                '[^A-Z0-9]', ''
            ) = 'PAYSDELALOIRE'
                THEN 'Pays de la Loire'
            WHEN REGEXP_REPLACE(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(TRIM(REGION)), 'À', 'A'), 'Â', 'A'), 'Ä', 'A'), 'Ç', 'C'), 'É', 'E'), 'È', 'E'), 'Ê', 'E'), 'Ë', 'E'), 'Î', 'I'), 'Ï', 'I'), 'Ô', 'O'), 'Ö', 'O'), 'Ù', 'U'), 'Û', 'U'), 'Ü', 'U'), 'Œ', 'OE'),
                '[^A-Z0-9]', ''
            ) = 'PROVENCEALPESCOTEDAZUR'
                THEN 'Provence-Alpes-Côte d''Azur'
            ELSE NULLIF(TRIM(REGION), '')
        END AS REGION,
        
        TRY_TO_NUMBER(YEAR_PATH_STARTED) AS YEAR_PATH_STARTED
    FROM source
),

filtered AS (
    SELECT
        USER_ID,
        PATH_CATEGORY_NAME,
        AGE_GROUP,
        GENDER,
        REGION,
        YEAR_PATH_STARTED
    FROM normalized
    WHERE USER_ID IS NOT NULL
      AND PATH_CATEGORY_NAME = 'Data'
      AND AGE_GROUP IN (
          '20-24 ans',
          '25-29 ans',
          '30-34 ans',
          '35-39 ans',
          '40-44 ans',
          '45-49 ans',
          '50-54 ans',
          '55-59 ans',
          '60 ans ou plus'
      )
      AND GENDER IN ('F', 'M', 'Non renseigné')
      AND REGION IS NOT NULL
      AND YEAR_PATH_STARTED IN (2022, 2023, 2024, 2025)
),

deduplicated AS (
    SELECT
        USER_ID,
        PATH_CATEGORY_NAME,
        AGE_GROUP,
        GENDER,
        REGION,
        YEAR_PATH_STARTED,
        ROW_NUMBER() OVER (
            PARTITION BY USER_ID, PATH_CATEGORY_NAME, AGE_GROUP, GENDER, REGION, YEAR_PATH_STARTED
            ORDER BY USER_ID
        ) AS rn
    FROM filtered
)

SELECT
    USER_ID,
    PATH_CATEGORY_NAME,
    AGE_GROUP,
    GENDER,
    REGION,
    YEAR_PATH_STARTED
FROM deduplicated
WHERE rn = 1
