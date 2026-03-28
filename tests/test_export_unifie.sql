SELECT *
FROM fct_export_unifie
WHERE gender NOT IN ('F', 'M')
   OR age_group IS NULL
   OR gender IS NULL
   OR nb_etudiants IS NULL
   OR region IS NULL
   OR year IS NULL