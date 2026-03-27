-- Table de fait : Profil sociodémographique des étudiants
-- Agrégation par année, région, tranche d'âge et genre
-- La source est la couche intermediate pour respecter l'architecture 3 couches.
{{ config(materialized='table') }}
WITH joined_data AS (
    SELECT * FROM {{ ref('int_etudiants_insee_joined') }}
),

aggregated AS (
    SELECT
        YEAR_PATH_STARTED,
        REGION,
        AGE_GROUP,
        GENDER,
        PATH_CATEGORY_NAME,
        COUNT(DISTINCT USER_ID) AS nb_etudiants
    FROM joined_data
    WHERE USER_ID IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5
)

SELECT * 
FROM aggregated
ORDER BY YEAR_PATH_STARTED DESC, REGION, AGE_GROUP, GENDER