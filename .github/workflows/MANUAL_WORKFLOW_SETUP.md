# 🚀 Configuration & Lancement manuel du Workflow GitHub Actions

## 📋 Prérequis

- ✅ Repo GitHub créé avec le dossier `.github/workflows/`
- ✅ Fichier `dbt-ci.yml` commité
- ✅ Secrets Snowflake configurés dans GitHub
- ✅ Branche `main` ou `develop` existante

---

## ⚙️ ÉTAPE 1 : Configurer les Secrets GitHub

### 1.1 Allez dans les Settings du repo
```
https://github.com/<YOUR_USERNAME>/<YOUR_REPO>/settings
```

### 1.2 Menu → Secrets and variables → Actions
```
Settings
  └─ Secrets and variables
      └─ Actions
          └─ New repository secret
```

### 1.3 Ajouter les 7 secrets Snowflake

| Secret Name | Valeur | Exemple |
|------------|--------|---------|
| `SNOWFLAKE_ACCOUNT` | ID compte Snowflake (sans .snowflakecomputing.com) | `rnshnff-ul10359` |
| `SNOWFLAKE_USER` | Utilisateur Snowflake | `votre_utilisateur` |
| `SNOWFLAKE_PASSWORD` | Mot de passe | `*****` |
| `SNOWFLAKE_ROLE` | Role Snowflake | `ACCOUNTADMIN` |
| `SNOWFLAKE_WAREHOUSE` | Warehouse | `P8_WAREHOUSE` |
| `SNOWFLAKE_DATABASE` | Database | `P8_OPENCLASSROOMS` |
| `SNOWFLAKE_SCHEMA` | Schema | `RAW_DATA` |

**Copier depuis votre `profiles.yml` local :**
```powershell
# Windows PowerShell - Option 1
Get-Content $HOME\.dbt\profiles.yml | Select-String "account|user|password|role|warehouse|database|schema"

# Windows PowerShell - Option 2
cat $HOME\.dbt\profiles.yml | Select-String "account|user|password|role|warehouse|database|schema"
```

### 1.4 Vérifier les secrets configurés
```
Settings → Secrets and variables → Actions → [Liste affichée]
```

---

## 📁 ÉTAPE 2 : Vérifier la structure du repo GitHub

```
votre-repo/
├── .github/
│   └── workflows/
│       └── dbt-ci.yml          ✅ Fichier contenant le workflow
├── P8--DBT/
│   ├── dbt_project.yml
│   ├── profiles.yml
│   ├── models/
│   │   ├── staging/
│   │   ├── intermediate/
│   │   └── marts/
│   └── tests/
├── exports/                     (créé par dbt)
├── README.md
└── .gitignore
```

**Vérifier que tout est commité :**
```bash
git status
# Pas de fichiers en pending
```

---

## 🔧 ÉTAPE 3 : Vérifier la configuration du Workflow

### 3.1 Vérifier le déclencheur
Ouvrir `.github/workflows/dbt-ci.yml` et vérifier :

```yaml
name: dbt CI/CD

on:
  push:
    branches:
      - main
      - develop
  workflow_dispatch:          # ← Ce ligne active le déclenchement MANUEL
```

**Le `workflow_dispatch` permet de lancer le workflow manuellement depuis l'UI GitHub.**

### 3.2 Vérifier les jobs
```yaml
jobs:
  lint-compile:               # ← Job 1
    runs-on: ubuntu-latest
    ...
  build:                      # ← Job 2 (dépend de lint-compile)
    needs: lint-compile
    if: github.ref == 'refs/heads/main' || github.event_name == 'workflow_dispatch'
    ...
  export-csv:                 # ← Job 3 (dépend de build)
    needs: build
    if: github.ref == 'refs/heads/main' || github.event_name == 'workflow_dispatch'
    ...
```

---

## ▶️ ÉTAPE 4 : Déclencher le Workflow Manuellement

### Option A : Via GitHub UI (Recommandé)

#### 4A.1 Allez dans l'onglet "Actions"
```
https://github.com/<YOUR_USERNAME>/<YOUR_REPO>/actions
```

#### 4A.2 Sélectionnez le workflow
```
Left sidebar:
  └─ dbt CI/CD  ← Cliquer ici
```

#### 4A.3 Bouton "Run workflow"
```
Yellow banner: "This workflow has a workflow_dispatch event trigger"
Bouton: [Run workflow ▼]
```

#### 4A.4 Configuration du lancement
```
Branch:  main  [Sélectionner main ou develop]
         ↓
[Run workflow] (bouton vert)
```

#### 4A.5 Confirmer
Après clic, GitHub crée un **Run ID** et le workflow démarre.

---

### Option B : Via CLI GitHub (gh)

Si vous avez GitHub CLI installé :

```bash
# 1. Authentifier
gh auth login

# 2. Déclencher le workflow
gh workflow run dbt-ci.yml --repo <USERNAME>/<REPO> --ref main

# 3. Voir le statut
gh run list --repo <USERNAME>/<REPO> --workflow dbt-ci.yml

# Output:
# WORKFLOW NAME  STATUS    CONCLUSION  ID         CREATED
# dbt CI/CD      ✓ Completed success   12345678  2026-03-24T15:00:00Z
```

---

### Option C : Via curl (Avancé)

```bash
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  "https://api.github.com/repos/<USERNAME>/<REPO>/actions/workflows/dbt-ci.yml/dispatches" \
  -d '{"ref":"main"}'
```

(Nécessite un Personal Access Token GitHub)

---

## 📊 ÉTAPE 5 : Monitorer l'exécution

### 5.1 Vue d'ensemble des jobs
```
Actions → dbt CI/CD → Run #<ID>
│
├─ lint-compile     ⏳ In Progress → ✅ Completed
│   └─ dbt parse (30 sec)
│
├─ build            ⏳ Waiting... (après lint-compile)
│   ├─ dbt run – staging
│   ├─ dbt test – staging  
│   ├─ dbt run – intermediate
│   └─ dbt build – marts (run + test)
│
└─ export-csv            ⏳ Waiting... (après build)
    ├─ Export fct_export_unifie (CSV)
    └─ Upload CSV export
```

### 5.2 Logs détaillés
Cliquer sur un job pour voir les logs :

```
build → dbt build – marts
└─ Voir les 100+ lignes de SQL compilé
└─ Voir les résultats: "633 rows created ✓"
```

### 5.3 Timeline estimée
| Étape | Durée | Statut |
|-------|-------|--------|
| lint-compile | 30s | ✅ |
| build staging | 1m | ✅ |
| build intermediate | 45s | ✅ |
| build marts | 90s | ✅ |
| export-csv | 45s | ✅ |
| **Total** | **~5 min** | ✅ |

---

## 📥 ÉTAPE 6 : Récupérer les Artefacts

### 6.1 Via GitHub UI

```
Actions → dbt CI/CD → Run #<ID>
│
└─ Artifacts (en bas de page)
    ├─ dbt-artifacts-<RUN_ID>          (run_results.json, manifest.json)
    └─ marts-csv-<RUN_ID>               ← **CSV EXPORT** ✅
```

### 6.2 Télécharger le CSV

1. Cliquer sur `marts-csv-<RUN_ID>`
2. Fichier ZIP auto-téléchargé
3. Extraire : `exports/fct_export_unifie.csv`

```
fct_export_unifie.csv (125 KB, 633 lignes)
│
├─ Headers: year,region,age_group,gender,nb_etudiants,...
├─ Row 1:   2025,Auvergne-Rhône-Alpes,20-24,F,45,...
├─ Row 2:   2025,Auvergne-Rhône-Alpes,20-24,M,75,...
└─ ...
```

### 6.3 Via CLI GitHub

```bash
# Lister les artifacts
gh run download <RUN_ID> --repo <USERNAME>/<REPO>

# Output:
# Downloaded 2 artifacts to current directory
```

---

## 🔍 ÉTAPE 7 : Diagnostiquer les erreurs

### Si lint-compile échoue ❌

```
Actions → lint-compile → dbt parse
└─ Logs: "Syntax error in models/marts/fct_export_unifie.sql:45"
└─ Fix: Corriger le SQL → git push → retry
```

### Si build échoue ❌

```
Actions → build → dbt build – marts
└─ Logs: "Object 'FCT_EXPORT_UNIFIE' does not exist"
└─ Causes possibles:
   1. Secrets Snowflake incorrects → Vérifier Settings
   2. Warehouse/Database down → Vérifier Snowflake UI
   3. Permissions insuffisantes → GRANT à l'utilisateur CI
```

### Si export-csv échoue ❌

```
Actions → export-csv → Export fct_export_unifie
└─ Logs: "CSV_ROWS: 0" ou "CSV file empty"
└─ Fix: Vérifier que la table fct_export_unifie a des données
   SELECT COUNT(*) FROM P8_OPENCLASSROOMS.RAW_DATA.FCT_EXPORT_UNIFIE;
```

---

## ✅ ÉTAPE 8 : Vérifier le succès

### Checklist de succès

```
☑️  Workflow déclenché manuellement via "Run workflow"
☑️  Job "lint-compile" : ✅ Passed (syntax check OK)
☑️  Job "build" : ✅ Passed (dbt run + tests OK)
☑️  Job "export-csv" : ✅ Passed (CSV créé, 633 lignes)
☑️  Artifacts générés : marts-csv-<RUN_ID> disponible
☑️  CSV téléchargé et vérifié localement
☑️  Données cohérentes (year, region, gender, nb_etudiants)
```

---

## 🔄 ÉTAPE 9 : Relancer automatiquement (optionnel)

### 9.1 Déclencher à chaque push

Le workflow **se déclenche automatiquement** sur :
```yaml
on:
  push:
    branches:
      - main
      - develop
    paths:
      - 'P8--DBT/**'  # Seulement si fichiers dbt modifiés
```

**Exemple :**
```bash
git add P8--DBT/models/marts/fct_export_unifie.sql
git commit -m "Update fct_export_unifie"
git push origin main
# → GitHub Actions se déclenche automatiquement
# → Email notification après ~5 min
```

### 9.2 Déclencher selon une planification (cron)

Optionnel : Ajouter au `dbt-ci.yml` pour export quotidien :
```yaml
on:
  schedule:
    - cron: '0 2 * * *'  # 2h du matin chaque jour
  workflow_dispatch:     # + manuel
```

---

## 📞 Dépannage rapide

| Problème | Solution |
|----------|----------|
| Workflow n'apparaît pas | Vérifier que `dbt-ci.yml` est dans `.github/workflows/` |
| Bouton "Run workflow" grisé | Ajouter `workflow_dispatch:` dans `on:` du YAML |
| Workflow ne se déclenche pas | Pousser sur `main` (pas PR ou branche) |
| Secrets non reconnus | Vérifier la casse exacte du secret name |
| Snowflake connection failed | Vérifier credentials + IP whitelist Snowflake |
| CSV vide | Vérifier que `fct_export_unifie` a des données en Snowflake |

---

## 🎯 Résumé des commandes clés

```powershell
# 1. Mettre à jour le workflow localement
git add .github/workflows/dbt-ci.yml
git commit -m "Update workflow"
git push origin main

# 2. Aller dans GitHub UI
https://github.com/<USER>/<REPO>/actions

# 3. Cliquer "Run workflow" sur "dbt CI/CD"

# 4. Attendre ~5 minutes

# 5. Télécharger CSV depuis Artifacts

# 6. Vérifier données
notepad C:\Users\feria\Documents\P8\exports\fct_export_unifie.csv
```
