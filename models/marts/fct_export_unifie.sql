-- Mart d'export unifié : toutes les dimensions en une seule table
-- Grain : (year, region, age_group, gender)
-- Contient : nb_etudiants, population_insee, pct_femmes, gap
-- Ce modèle remplace les 3 exports séparés pour une distribution CSV unique.
{{ config(materialized='table') }}

WITH source AS (
    SELECT * FROM {{ ref('int_etudiants_insee_joined') }}
),

-- ── 1. Agrégation étudiants au grain fin (year, region, age_group, gender) ──
etu AS (
    SELECT
        YEAR_PATH_STARTED                           AS year,
        REGION                                      AS region,
        AGE_GROUP                                   AS age_group,
        AGE_GROUP_INSEE                             AS age_group_insee,
        GENDER                                      AS gender,
        PATH_CATEGORY_NAME,
        COUNT(DISTINCT USER_ID)                     AS nb_etudiants
    FROM source
    WHERE USER_ID IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5, 6
),

-- ── 1b. Total inscrits tous genres (F + M + Non renseigné) pour évolution annuelle ──
etu_all AS (
    SELECT
        YEAR_PATH_STARTED                           AS year,
        REGION                                      AS region,
        AGE_GROUP                                   AS age_group,
        AGE_GROUP_INSEE                             AS age_group_insee,
        COUNT(DISTINCT USER_ID)                     AS nb_inscrits_tous_genres
    FROM source
    WHERE USER_ID IS NOT NULL
    GROUP BY 1, 2, 3, 4
),

-- ── 2. Population INSEE dédupliquée au grain (year, region, age_group_insee, gender) ──
insee AS (
    SELECT DISTINCT
        year,
        insee_region                                AS region,
        insee_age_group                             AS age_group_insee,
        insee_gender                                AS gender,
        population_insee,
        nb_departments
    FROM source
    WHERE year IS NOT NULL
      AND population_insee IS NOT NULL
      AND insee_gender IN ('M', 'F')
),

-- ── 3. Jointure sur la clé de correspondance d'âge ──
joined AS (
    SELECT
        e.year,
        e.region,
        e.age_group,
        e.age_group_insee,
        e.gender,
        e.PATH_CATEGORY_NAME,
        e.nb_etudiants,
        a.nb_inscrits_tous_genres,
        i.population_insee,
        i.nb_departments
    FROM etu e
    LEFT JOIN etu_all a
        ON  e.year          = a.year
        AND e.region        = a.region
        AND e.age_group     = a.age_group
    LEFT JOIN insee i
        ON  e.year          = i.year
        AND e.region        = i.region
        AND e.age_group_insee = i.age_group_insee
        AND e.gender        = i.gender
    WHERE e.gender IN ('F', 'M')   -- exclut "Non renseigné" pour les comparaisons H/F
),

-- ── 4. Métriques de parité calculées par window (year, region) ──
with_metrics AS (
    SELECT
        year,
        region,
        age_group,
        age_group_insee,
        gender,
        PATH_CATEGORY_NAME,
        nb_etudiants,
        nb_inscrits_tous_genres,
        population_insee,
        nb_departments,

        -- Totaux régionaux (M+F) pour les pourcentages
        SUM(nb_etudiants)
            OVER (PARTITION BY year, region)          AS total_etu_region,
        SUM(population_insee)
            OVER (PARTITION BY year, region)          AS total_insee_region,

        -- Part étudiantes féminines et INSEE féminines (par region/year)
        SUM(CASE WHEN gender = 'F' THEN nb_etudiants     ELSE 0 END)
            OVER (PARTITION BY year, region)          AS nb_etu_f_region,
        SUM(CASE WHEN gender = 'F' THEN population_insee ELSE 0 END)
            OVER (PARTITION BY year, region)          AS nb_insee_f_region
    FROM joined
)

SELECT
    year,
    region,
    age_group,
    age_group_insee,
    gender,
    PATH_CATEGORY_NAME,
    nb_etudiants,                   -- effectif H ou F pour comparaisons de parité
    nb_inscrits_tous_genres,        -- effectif total (F + M + Non renseigné) pour évolution annuelle
    population_insee,
    nb_departments,
    total_etu_region,
    total_insee_region,

    -- % femmes OC dans la région/année (0–100)
    ROUND(
        100.0 * nb_etu_f_region / NULLIF(total_etu_region, 0),
        2
    )                                                  AS pct_femmes_etu,

    -- % femmes INSEE dans la région/année (0–100)
    ROUND(
        100.0 * nb_insee_f_region / NULLIF(total_insee_region, 0),
        2
    )                                                  AS pct_femmes_insee,

    -- Écart de représentation féminine OC vs INSEE (points de %)
    ROUND(
        100.0 * nb_etu_f_region   / NULLIF(total_etu_region,   0)
      - 100.0 * nb_insee_f_region / NULLIF(total_insee_region, 0),
        2
    )                                                  AS gap_femmes_pct

FROM with_metrics
ORDER BY year DESC, region, age_group, gender
