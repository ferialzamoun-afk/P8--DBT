-- Table d'analyse : agrégation INSEE par région, année, classe d'âge et genre
-- Source : couche intermediate pour alignement avec l'architecture 3 couches.
{{ config(materialized='table') }}
WITH joined_data AS (
    SELECT * FROM {{ ref('int_etudiants_insee_joined') }}
),

-- Déduplication des lignes INSEE répétées sur les lignes étudiants
insee_base AS (
    SELECT DISTINCT
        year,
        insee_region AS region,
        insee_age_group AS age_group,
        insee_gender AS gender,
        population_insee,
        nb_departments
    FROM joined_data
    WHERE year IS NOT NULL
      AND population_insee IS NOT NULL
),

aggregated AS (
    SELECT
        year,
        region,
        age_group,
        gender,
        CASE WHEN gender = 'ALL' THEN 'Ensemble' ELSE gender END AS gender_label,
        SUM(population) AS population_insee,
        MAX(nb_departments) AS nb_departments
    FROM (
        SELECT
            year,
            region,
            age_group,
            gender,
            population_insee AS population,
            nb_departments
        FROM insee_base
    ) src
    WHERE gender IN ('M', 'F', 'ALL')
    GROUP BY 1, 2, 3, 4, 5
)

SELECT * 
FROM aggregated
ORDER BY year DESC, region, age_group, gender