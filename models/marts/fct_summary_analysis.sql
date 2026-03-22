-- Mart de synthese : comparaison etudiants vs INSEE
-- Grain: annee, region, genre
{{ config(materialized='table') }}
WITH joined_data AS (
    SELECT *
    FROM {{ ref('int_etudiants_insee_joined') }}
),

etudiants_agg AS (
    SELECT
        YEAR_PATH_STARTED AS year,
        REGION AS region,
        GENDER AS gender,
        COUNT(DISTINCT USER_ID) AS nb_etudiants
    FROM joined_data
    WHERE USER_ID IS NOT NULL
      AND GENDER IN ('F', 'M')
    GROUP BY 1, 2, 3
),

insee_base AS (
    SELECT DISTINCT
        year,
        insee_region AS region,
        insee_gender AS gender,
        insee_age_group AS age_group,
        population_insee
    FROM joined_data
    WHERE year IS NOT NULL
      AND insee_gender IN ('F', 'M')
      AND population_insee IS NOT NULL
),

insee_agg AS (
    SELECT
        year,
        region,
        gender,
        SUM(population_insee) AS population_insee
    FROM insee_base
    GROUP BY 1, 2, 3
),

merged AS (
    SELECT
        COALESCE(e.year, i.year) AS year,
        COALESCE(e.region, i.region) AS region,
        COALESCE(e.gender, i.gender) AS gender,
        COALESCE(e.nb_etudiants, 0) AS nb_etudiants,
        COALESCE(i.population_insee, 0) AS population_insee,
        CASE
            WHEN e.nb_etudiants IS NOT NULL AND i.population_insee IS NOT NULL THEN 'matched'
            WHEN e.nb_etudiants IS NOT NULL AND i.population_insee IS NULL THEN 'etudiants_only'
            WHEN e.nb_etudiants IS NULL AND i.population_insee IS NOT NULL THEN 'insee_only'
            ELSE NULL
        END AS join_scope,
        SUM(COALESCE(e.nb_etudiants, 0)) OVER (
            PARTITION BY COALESCE(e.year, i.year), COALESCE(e.region, i.region)
        ) AS total_etudiants_region_year,
        SUM(COALESCE(i.population_insee, 0)) OVER (
            PARTITION BY COALESCE(e.year, i.year), COALESCE(e.region, i.region)
        ) AS total_insee_region_year
    FROM etudiants_agg e
    FULL OUTER JOIN insee_agg i
        ON e.year = i.year
        AND e.region = i.region
        AND e.gender = i.gender
)

SELECT
    year,
    region,
    gender,
    join_scope,
    nb_etudiants,
    population_insee,
    CASE
        WHEN total_etudiants_region_year > 0 THEN nb_etudiants / total_etudiants_region_year
        ELSE NULL
    END AS part_etudiants,
    CASE
        WHEN total_insee_region_year > 0 THEN population_insee / total_insee_region_year
        ELSE NULL
    END AS part_insee,
    (
        CASE
            WHEN total_etudiants_region_year > 0 THEN nb_etudiants / total_etudiants_region_year
            ELSE NULL
        END
        -
        CASE
            WHEN total_insee_region_year > 0 THEN population_insee / total_insee_region_year
            ELSE NULL
        END
    ) * 100 AS ecart_points
FROM merged
ORDER BY year DESC, region, gender
