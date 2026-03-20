-- Couche intermediate : jointure étudiants / INSEE
-- Objectif : centraliser la logique de rapprochement sur des dimensions communes
-- (annee, region, genre, classe d'age INSEE) avant exposition en marts.

WITH etudiants AS (
    SELECT
        USER_ID,
        PATH_CATEGORY_NAME,
        AGE_GROUP,
        GENDER,
        REGION,
        YEAR_PATH_STARTED,
        CASE
            WHEN AGE_GROUP IN ('20-24 ans', '25-29 ans', '30-34 ans', '35-39 ans') THEN '20-39 ans'
            WHEN AGE_GROUP IN ('40-44 ans', '45-49 ans', '50-54 ans', '55-59 ans') THEN '40-59 ans'
            WHEN AGE_GROUP = '60 ans ou plus' THEN '60+ ans'
            ELSE NULL
        END AS AGE_GROUP_INSEE
    FROM {{ ref('stg_etudiants') }}
),

insee_agg AS (
    SELECT
        year,
        region_name_standardized AS region,
        age_group_insee,
        gender_insee AS gender,
        SUM(population) AS population_insee,
        COUNT(DISTINCT region_code) AS nb_departments
    FROM {{ ref('stg_insee_population') }}
    WHERE gender_insee IN ('M', 'F', 'ALL')
    GROUP BY 1, 2, 3, 4
),

joined AS (
    SELECT
        e.USER_ID,
        e.PATH_CATEGORY_NAME,
        e.AGE_GROUP,
        e.GENDER,
        e.REGION,
        e.YEAR_PATH_STARTED,
        e.AGE_GROUP_INSEE,
        i.year,
        i.region AS insee_region,
        i.age_group_insee AS insee_age_group,
        i.gender AS insee_gender,
        i.population_insee,
        i.nb_departments,
        CASE
              WHEN e.YEAR_PATH_STARTED IS NOT NULL AND i.year IS NOT NULL THEN 'matched'
              WHEN e.YEAR_PATH_STARTED IS NOT NULL THEN 'etudiants_only'
              ELSE 'insee_only'
        END AS match_status
    FROM etudiants e
    FULL OUTER JOIN insee_agg i
        ON e.YEAR_PATH_STARTED = i.year
        AND e.REGION = i.region
        AND e.GENDER = i.gender
        AND e.AGE_GROUP_INSEE = i.age_group_insee
)

SELECT *
FROM joined
