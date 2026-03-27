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
            WHEN TRIM(REGION) IN ('Guadeloupe', 'Martinique', 'Réunion', 'La Réunion', 'Guyane')
                THEN 'DROM'
            WHEN TRIM(REGION) = 'DOM'
                THEN 'DROM'
            WHEN TRIM(REGION) IN ('Auvergne-Rhone-Alpes', 'Auvergne-Rhône-Alpes')
                THEN 'Auvergne-Rhône-Alpes'
            WHEN TRIM(REGION) IN ('Bourgogne-Franche-Comte', 'Bourgogne-Franche-Comté')
                THEN 'Bourgogne-Franche-Comté'
            WHEN TRIM(REGION) = 'Centre-Val de Loire'
                THEN 'Centre-Val-de-Loire'
            WHEN TRIM(REGION) IN ('Grand-Est', 'Grand Est')
                THEN 'Grand Est'
            WHEN TRIM(REGION) IN ('Ile-de-France', 'Île-de-France')
                THEN 'Île-de-France'
            WHEN TRIM(REGION) IN ('Pays-de-la-Loire', 'Pays de la Loire')
                THEN 'Pays de la Loire'
            WHEN TRIM(REGION) IN ('Provence-Alpes-Cote-d-Azur', 'Provence-Alpes-Côte d''Azur')
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
