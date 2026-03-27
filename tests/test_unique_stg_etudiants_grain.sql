-- Verify that a cleaned student record appears only once.
-- This tests uniqueness on the full business grain of stg_etudiants.

WITH duplicates AS (
    SELECT
        USER_ID,
        PATH_CATEGORY_NAME,
        AGE_GROUP,
        GENDER,
        REGION,
        YEAR_PATH_STARTED,
        COUNT(*) AS row_count
    FROM {{ ref('stg_etudiants') }}
    GROUP BY
        USER_ID,
        PATH_CATEGORY_NAME,
        AGE_GROUP,
        GENDER,
        REGION,
        YEAR_PATH_STARTED
    HAVING COUNT(*) > 1
)

SELECT *
FROM duplicates
