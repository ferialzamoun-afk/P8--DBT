# 📊 P8 - OpenClassrooms : Analyse comparée Étudiants vs INSEE

> **Données à jour** | **Pipeline contrôlé** | **Exports automatisés** | **Reporting en temps réel**

---

## 🎯 Contexte & Objectifs

### Contexte
Ce projet analyse la **représentativité des étudiants OpenClassrooms** par rapport à la population française (données INSEE). L'objectif est d'identifier les **lacunes de couverture par région, genre et groupe d'âge** pour améliorer les stratégies de recrutement et d'inclusion.

### Données source
- 📚 **Étudiants OC** : Données de plateforme OpenClassrooms (2022-2025)
- 🇫🇷 **INSEE** : Population française par région/genre/âge (2022-2025)
- 🗺️ **Géographie** : Harmonisation région/département avec référentiel INSEE

### Objectifs analytiques
```
1. Calculer le taux de pénétration OC par région
2. Analyser les écarts de représentation par genre
3. Identifier les groupes d'âge sous-représentés
4. Produire des indicateurs de tendance annuels (2022-2025)
5. Délivrer des exports CSV pour Power BI et reporting
```

**KPIs clés :**
- % de femmes étudiants vs % femmes population INSEE
- Ratio : nb étudiants / population totale par région
- Écart de représentation par groupe d'âge (20-24, 25-29, ..., 60+)

---

## 🏗️ Architecture & Méthodologie

### Stack technique
| Composant | Outil | Version |
|-----------|------|---------|
| **Data Pipeline** | dbt (transform) | 1.11.7 |
| **Data Warehouse** | Snowflake | (Cloud/SaaS) |
| **Orchestration** | GitHub Actions | (CI/CD) |
| **Visualization** | Power BI / Streamlit | (En développement) |
| **Stockage exports** | GitHub Artifacts | (90 jours) |

### Modèle de données (3 couches)

```
┌─────────────────────────────────────────┐
│     MARTS (Tables d'export)             │
│  ├─ fct_export_unifie (Analyse unifiée) │
│  └─ (Dashboards Power BI)               │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────────────────────────────┐
│   INTERMEDIATE (Transformations)        │
│  ├─ int_etudiants_insee_joined (FULL)   │
│  └─ (Jointures complexes, dédupli)      │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────────────────────────────┐
│    STAGING (Nettoyage & enrichissement) │
│  ├─ stg_etudiants (Harmonisation genres)│
│  ├─ stg_insee_population (Agrégation)   │
│  └─ (Filtres, transformations brutes)   │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────────────────────────────┐
│   SOURCES (Données brutes importées)    │
│  ├─ raw_etudiants.csv                   │
│  ├─ raw_insee_population.csv            │
│  └─ raw_geo_ref.csv (Territoire)        │
└─────────────────────────────────────────┘
```

### Processus dbt : 3 étapes principales

#### **1️⃣ STAGING : Nettoyage & Harmonisation**
```sql
-- stg_etudiants.sql
SELECT
  ANNÉE,
  REGION,  -- Harmonisation accents/DOM-TOM
  AGE_GROUP,  -- Normalisation "30 à 34 ans" → "30-34"
  GENDER,  -- Mapping H/F → M/F
  COUNT(*) as nb_etudiants
FROM raw_etudiants
WHERE annee >= 2022  -- Filtrage period
GROUP BY 1,2,3,4
```

**Résultat :** Données cohérentes, sans anomalies

---

#### **2️⃣ INTERMEDIATE : Jointures & Agrégations**
```sql
-- int_etudiants_insee_joined.sql
WITH etudiants AS (
  SELECT ... FROM stg_etudiants
),
insee_agg AS (
  SELECT ... FROM stg_insee_population
)
SELECT
  e.year, e.region, e.age_group, e.gender,
  e.nb_etudiants,
  i.population_insee,
  CASE 
    WHEN e.year IS NOT NULL THEN 'matched'
    WHEN i.year IS NOT NULL THEN 'insee_only'
    ELSE 'students_only'
  END as match_status
FROM etudiants e
FULL OUTER JOIN insee_agg i
  ON e.year = i.year
  AND e.region = i.region
  AND e.gender = i.gender
  AND e.age_group = i.age_group
```

**Résultat :** Vue unifiée student + INSEE prête pour calculs

---

#### **3️⃣ MARTS : Indicateurs & Export**
```sql
-- fct_export_unifie.sql (TABLE MATÉRIALISÉE)
SELECT
  year, region, age_group, gender,
  nb_etudiants,
  population_insee,
  ROUND(100.0 * nb_etudiants / NULLIF(population_insee, 0), 2) as penetration_pct,
  ROUND(
    100.0 * COUNT(CASE WHEN gender='F' THEN 1 END) 
      / NULLIF(COUNT(*), 0),
    2
  ) as pct_femmes_etu,
  ROUND(
    100.0 * COUNT(CASE WHEN gender='F' THEN 1 END) 
      / NULLIF(SUM(population_insee), 0),
    2
  ) as pct_femmes_insee
  -- Gap calcul pour analyste
FROM int_etudiants_insee_joined
WHERE year BETWEEN 2022 AND 2025
GROUP BY 1,2,3,4
ORDER BY year DESC, region, age_group, gender
```

**Résultat :** **633 lignes** prêtes pour Power BI / export CSV

---

## 🔄 Pipeline CI/CD

### Déclenche automatiquement sur :
- ✅ Push `main` ou `develop` (dossier `P8--DBT/**`)
- ✅ Pull Request sur `main`
- ✅ Déclenchement manuel (`workflow_dispatch`)

### Workflow dbt-ci.yml : 3 jobs

```
┌─────────────────────────────────────────────────────┐
│ JOB 1: lint-compile (Syntax check)                  │
│ ├─ dbt parse (vérifie tous les modèles)             │
│ └─ Durée : ~30 sec                                  │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────────────────────────────────────────┐
│ JOB 2: build (Run + Test) [needs: lint-compile]     │
│ ├─ dbt run ── staging (fixtures + tests)             │
│ ├─ dbt test ── staging (6 tests)                     │
│ ├─ dbt run ── intermediate                           │
│ ├─ dbt build ── marts (run + test)                   │
│ ├─ Upload artifacts (run_results.json, manifest)    │
│ └─ Durée : ~3-5 min                                 │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────────────────────────────────────────┐
│ JOB 3: export-csv [needs: build]                    │
│ ├─ dbt show ── fct_export_unifie --output csv       │
│ ├─ Résultat : 633 lignes, ~125 KB                   │
│ ├─ Upload artifact : marts-csv-<RUN_ID>            │
│ └─ Webhook Power BI (optionnel)                     │
│    └─ Durée : ~45 sec                               │
└──────────────────────────────────────────────────────┘
```

**Total** : ~5-8 minutes de bout en bout

---

## 📥 Récupérer les résultats

### Artefacts disponibles

| Artefact | Format | Lieu | Usage |
|----------|--------|------|-------|
| **fct_export_unifie.csv** | CSV | GitHub Artifacts | Power BI, Streamlit, Excel |
| **dbt artifacts** | JSON | GitHub Artifacts | Lineage, tests, logs |
| **Logs dbt** | Text | GitHub Actions UI | Debugging |

### Télécharger le CSV d'export

```bash
# Via GitHub UI
1. Actions → dbt CI/CD → Run #<ID>
2. Artifacts → marts-csv-<RUN_ID>
3. Download ZIP → Extract CSV

# Via CLI
gh run download <RUN_ID> --repo <USER>/<REPO>
```

---

## 🚀 Utilisation locale

### Setup initial

```powershell
# 1. Cloner le repo
git clone https://github.com/<USER>/P8.git
cd P8

# 2. Créer venv
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# 3. Installer dbt
pip install dbt-snowflake==1.11.3

# 4. Configurer dbt profiles
# → C:\Users\<USER>\.dbt\profiles.yml

# 5. Charger variables d'env
. ./load-env.ps1
cd P8--DBT
```

### Commandes principales

```powershell
# Vérifier la connexion
dbt debug --target dev_password

# Exécuter les modèles
dbt run --target dev_password

# Tester les données
dbt test --select fct_export_unifie

# Prévisualiser le résultat
dbt show --select fct_export_unifie --limit 10

# Générer la documentation
dbt docs generate && dbt docs serve
```

---

## 📈 Streamlit Dashboard

### Objectif
Dashboard interactif pour explorer les resultats d'export en temps reel.

### Implémente

```
┌─────────────────────────────────────┐
│    STREAMLIT APP (local)            │
├─────────────────────────────────────┤
│ 1. Filtres interactifs              │
│    ├─ Année (2022-2025)             │
│    ├─ Région                        │
│    ├─ Genre                         │
│    └─ Groupe d'âge                  │
│                                     │
│ 2. Visualisations                   │
│    ├─ Taux pénétration par région   │
│    ├─ Gap femmes (étudiants/INSEE)  │
│    ├─ Trends annuels                │
│    └─ Heatmap région × genre        │
│                                     │
│ 3. Exports interactifs              │
│    ├─ Télécharger CSV filtré        │
│    └─ Table détaillée filtrable     │
└─────────────────────────────────────┘
```

### Lancer en local

```bash
pip install -r requirements-streamlit.txt
streamlit run streamlit_app.py
```

URL locale: http://localhost:8501

### Lien Streamlit (futur)
https://your-streamlit-app.com

### Technologies
- **Framework** : Streamlit
- **Source données** : `outputs/pbi_region_repr.csv`, `outputs/pbi_women_oc_vs_insee.csv`, `outputs/pbi_trend_etu_year_total.csv`, `outputs/pbi_repartition_age_oc.csv`, `outputs/pbi_heat_region_gender.csv`
- **Visualisations** : Plotly, Pandas
- **Déploiement** : Streamlit Cloud ou Heroku

---

## 📋 Structure du repo

```
P8/
├── .github/
│   ├── workflows/
│   │   ├── dbt-ci.yml                    ← Workflow principal
│   │   ├── MANUAL_WORKFLOW_SETUP.md      ← Guide lancement manuel
│   │   ├── POWER_BI_SETUP.md             ← Intégration Power BI
│   │   └── helpers/
│   │
├── P8--DBT/                              ← Projet dbt principal
│   ├── dbt_project.yml                   ← Configuration dbt
│   ├── profiles.yml                      ← Connexion Snowflake
│   ├── models/
│   │   ├── staging/                      ← Nettoyage brut
│   │   │   ├── stg_etudiants.sql
│   │   │   └── stg_insee_population.sql
│   │   ├── intermediate/                 ← Transformations
│   │   │   └── int_etudiants_insee_joined.sql
│   │   └── marts/                        ← Tables d'export
│   │       └── fct_export_unifie.sql
│   ├── tests/                            ← Tests dbt
│   │   └── test_unique_stg_etudiants_grain.sql
│   ├── src/                              ← Scripts/utilitaires
│   │   ├── enrich_insee_population.py
│   │   ├── extract_insee_population.py
│   │   └── build_pbi_unified_export.py
│   └── target/                           ← Artifacts générés
│
├── data/                                 ← Données centralisées
│   ├── raw/                              ← Sources brutes (fichiers d'origine)
│   │   ├── Estimation_popu_2025_dpt_sexe_classe_age.xlsx
│   │   ├── fr-esr-referentiel-geographique.csv
│   │   └── geo_ref_template_for_snowflake.csv
│   └── processed/                        ← Données transformées/enrichies
│       ├── fct_export_unifie.csv         ← PRINCIPAL (dbt export)
│       ├── 5-Profil_sociodemo_output_csv_2026-03-20-1903.csv
│       ├── 6-Comparaison_insee_region_age_genre_2026-03-20-1909.csv
│       ├── insee_population_enrichi.csv
│       └── insee_population_departements_wide_2022_2025.csv
│
├── logs/                                 ← Logs d'exécution
├── load-env.ps1                          ← Setup local (Windows)
├── analyse_csv_p8.ipynb                  ← Analyses exploratoires
│
├── README.md                             ← Ce fichier
├── CSV_EXPORT_VALUE_CHAIN.md             ← Chaîne valeur
└── .gitignore
```

---

## 🔐 Configuration des accès

### Secrets GitHub requis

```
Settings → Secrets and variables → Actions
├─ SNOWFLAKE_ACCOUNT
├─ SNOWFLAKE_USER
├─ SNOWFLAKE_PASSWORD
├─ SNOWFLAKE_ROLE
├─ SNOWFLAKE_WAREHOUSE
├─ SNOWFLAKE_DATABASE
└─ SNOWFLAKE_SCHEMA
```

### Permissions Snowflake

```sql
-- Compte utilisateur CI doit avoir :
GRANT USAGE ON DATABASE P8_OPENCLASSROOMS TO ROLE <CI_ROLE>;
GRANT USAGE ON SCHEMA RAW_DATA TO ROLE <CI_ROLE>;
GRANT CREATE TABLE ON SCHEMA RAW_DATA TO ROLE <CI_ROLE>;
GRANT INSERT, SELECT ON ALL TABLES IN SCHEMA RAW_DATA TO ROLE <CI_ROLE>;
```

---

## 🚦 États du Pipeline

| État | Signification | Action |
|------|--------------|--------|
| ✅ Passed | Workflow réussi | ✓ Export prêt |
| 🟡 In Progress | Execution en cours | ⏳ Attendre |
| ❌ Failed | Erreur dbt/Snowflake | 🔧 Voir logs |
| ⏭️ Skipped | Condition not met | (PR ou branche) |

---

## 📞 Support & Dépannage

### Commandes utiles

```powershell
# Voir les logs locaux
Get-Content logs/dbt.log | Select-Object -Last 50

# Compiler un modèle spécifique
dbt compile --select fct_export_unifie --inline

# Voir la dépendance des modèles
dbt deps && dbt docs generate

# Tester avant push
dbt test --select staging --fail-fast
```

### Ressources
- 📚 [dbt Documentation](https://docs.getdbt.com)
- 🏂 [Snowflake Setup](https://docs.snowflake.com)
- 🔑 [GitHub Actions](https://docs.github.com/actions)
- 📊 [Power BI Integration](Microsoft Power Automate docs)

---

## 🎓 Améliorations futures

- [ ] Dashboard Streamlit interactif
- [ ] Intégration Power BI webhook (Power Automate)
- [ ] Modèles prédictifs (machine learning)
- [ ] API REST pour accès programmatique
- [ ] Alertes Slack/Teams sur anomalies
- [ ] Versionning des exports (historique)

---

## 📅 Releases

| Version | Date | Changements |
|---------|------|-------------|
| **v1.0** | 2026-03-24 | Export initial `fct_export_unifie` (633 lignes) |
| v0.9 | - | Configuration CI/CD GitHub Actions |
| v0.5 | - | Setup dbt + Snowflake |

---

## 📄 Licence

Projet OpenClassrooms - Données sensibles (accès restreint)

---

**👉 Démarrer** : [MANUAL_WORKFLOW_SETUP.md](.github/workflows/MANUAL_WORKFLOW_SETUP.md)

**📚 Architecture** : [CSV_EXPORT_VALUE_CHAIN.md](CSV_EXPORT_VALUE_CHAIN.md)

**🔌 Power BI** : [POWER_BI_SETUP.md](.github/workflows/POWER_BI_SETUP.md)
