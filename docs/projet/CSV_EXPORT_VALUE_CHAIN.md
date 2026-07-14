# 📊 Chaîne de création de valeur : CSV Export

## Vue d'ensemble

```
LOCAL WORKFLOW                          GITHUB ACTIONS WORKFLOW
═══════════════════════════════════     ════════════════════════════════════

①  Développement modèles SQL            ④ dbt parse (syntax check)
    ↓                                     ↓
②  dbt run local (staging/intermediate) ⑤ dbt run (staging/intermediate/marts)
    ↓                                     ↓
③  dbt test + validation data            ⑥ dbt test (validation data)
    ↓                                     ↓
(données testées en local)               ⑦ dbt show → export CSV
                                         ↓
                                         ⑧ upload artifact GitHub
                                         ↓
                                         ⑨ webhook Power BI (futur)
```

---

## 🏠 ÉTAPES EN LOCAL

### Étape 1 : Développement & Modification des modèles
```powershell
# Workspace: C:\Users\feria\Documents\P8\P8--DBT\models\

# Fichiers modifiables:
- models/staging/stg_etudiants.sql          → nettoyage donnees brutes
- models/intermediate/int_*.sql             → transformations complexes  
- models/marts/fct_export_unifie.sql        → table cible pour export
```

**Artefacts générés** : `.sql` files dans dbt project

---

### Étape 2 : Exécution locale (dbt run)
```powershell
# Commande locale
Set-Location C:/Users/feria/Documents/P8
. ./load-env.ps1
Set-Location P8--DBT

dbt run --select staging,intermediate,marts --target dev_password
```

**Résultat** :
- ✅ Tables/vues créées dans Snowflake
- 📁 Artifacts: `target/compiled/`, `target/graph.gpickle`
- 🔍 Logs: `logs/dbt.log`

---

### Étape 3 : Validation locale (dbt test)
```powershell
dbt test --select staging,intermediate,marts --target dev_password
```

**Résultat** :
- ✅ 6 tests sur `fct_export_unifie` passent
- 📋 Test results: `target/run_results.json`
- 🚨 Stoppe si erreurs détectées

**Données validées = Prêtes pour l'export**

---

### ⚡ Optionnel : Prévisualiser le CSV en local
```powershell
dbt show --select fct_export_unifie --limit 633 --output csv > ../exports/preview_local.csv
```

---

## 🚀 ÉTAPES SUR GITHUB ACTIONS

### Étape 4 : Parse & Linting
```yaml
Job: lint-compile
├─ Checkout code
├─ Setup Python 3.11
├─ Install dbt-snowflake
├─ dbt parse (syntax check)
└─ ✅ Valide la syntaxe (pas de connexion Snowflake)
```

**Déclencheur** : Tout push/PR sur `P8--DBT/**`
**Durée** : ~30 secondes

---

### Étape 5 : Build complet (dbt run)
```yaml
Job: build
├─ needs: lint-compile (dépendance)
├─ Checkout + Setup Python
├─ dbt run –– staging
├─ dbt test –– staging (validation)
├─ dbt run –– intermediate  
├─ dbt build –– marts (run + test)
└─ Upload artifacts (run_results.json, manifest.json)
```

**Déclencheur** : Push `main` OU `workflow_dispatch`
**Durée** : ~3-5 minutes
**Output** : 
- Tables matérialisées dans Snowflake
- Artifacts stockés 30 jours

---

### Étape 6 : Export CSV  
```yaml
Job: export-csv
├─ needs: build (attend job build réussi)
├─ Checkout + Setup Python
├─ dbt show --select fct_export_unifie --limit 2000000 --output csv
└─ Pipe sortie → ../exports/fct_export_unifie.csv
```

**Format CSV généré** :
```
year,region,age_group,gender,nb_etudiants,nb_inscrits_tous_genres,...
2025,Auvergne-Rhône-Alpes,20-24,F,45,120,...
2025,Auvergne-Rhône-Alpes,20-24,M,75,120,...
```

**Artefact créé** :
- 📄 `exports/fct_export_unifie.csv` (633 lignes)
- 💾 Stocké 90 jours dans GitHub Artifacts

---

### Étape 7 : Upload Artifact
```yaml
- name: Upload CSV export
  uses: actions/upload-artifact@v4
  with:
    name: marts-csv-${{ github.run_id }}
    path: exports/fct_export_unifie.csv
```

**Accès** :
- GitHub Actions UI → Tab "Artifacts"  
- Téléchargeable directement après workflow
- Format: `marts-csv-<RUN_ID>.zip`

---

### Étape 8 : Webhook (Futur)
```yaml
- name: Webhook – Power BI
  if: success()
  run: |
    curl -X POST ${{ secrets.POWER_AUTOMATE_WEBHOOK_URL }} \
      -d '{"rowCount": 633, "status": "completed", ...}'
```

(À configurer plus tard avec Power BI)

---

## 📈 Chaîne de valeur détaillée

| Étape | Local/GitHub | Input | Processus | Output | Statut |
|-------|------------|-------|-----------|--------|--------|
| **1** | Local | Code SQL + CSV sources | Édition modèles | `.sql` files | Avant commit |
| **2** | Local | `.sql` + sources Snowflake | `dbt run` | Tables en Snowflake | Dev/Test |
| **3** | Local | Tables Snowflake | `dbt test` | Test results | ✅ Validation |
| **4** | GitHub | Code + dbt_project.yml | `dbt parse` | Syntax check | ✅ Lint |
| **5** | GitHub | Validated models | `dbt build` | Materialized tables | ✅ Build |
| **6** | GitHub | `fct_export_unifie` table | `dbt show --csv` | **CSV file** | ✅ Export |
| **7** | GitHub | CSV | `upload-artifact` | **GitHub Artifacts** | ✅ Storage |
| **8** | GitHub | Artifact metadata | Webhook POST | **Power BI trigger** | ⏳ Futur |

---

## 🔄 Flux complet (Exemple)

```
USER: git push -b main (P8--DBT/models/marts/fct_export_unifie.sql modifié)
            ↓
GITHUB: workflow_dispatch déclenché
            ↓
JOB 1 (lint-compile): dbt parse ✅ (30s)
            ↓
JOB 2 (build): 
    ├─ dbt run staging ✅ (1m)
    ├─ dbt test staging ✅ 
    ├─ dbt run intermediate ✅ (45s)
    └─ dbt build marts ✅ (90s) → Table `fct_export_unifie` créée
            ↓
JOB 3 (export-csv):
    ├─ dbt show → CSV (45s)
    ├─ Upload artifact ✅
    └─ Webhook (optionnel)
            ↓
RESULT: 
    ✅ Artifact disponible: marts-csv-<RUN_ID>
    ✅ CSV prêt pour PowerBI/distribution
    ⏱️  Total: ~5 minutes
```

---

## 📋 Checklist LOCAL

- [ ] Modèles SQL développés/testés localement
- [ ] `dbt run --target dev_password` fonctionne
- [ ] `dbt test --target dev_password` : tous les tests PASS
- [ ] `dbt show --limit 5` : données cohérentes
- [ ] Commit code modifié

## 📋 Checklist GITHUB

- [ ] Pusher code modifié sur `main` ou `develop`
- [ ] Workflow déclenché (voir Actions tab)
- [ ] Job `lint-compile` ✅
- [ ] Job `build` ✅ (dbt run + dbt test)
- [ ] Job `export-csv` ✅
- [ ] Artifact `marts-csv-<RUN_ID>` disponible
- [ ] Télécharger + vérifier CSV

---

## 🎯 Métriques de succès

| Métrique | Local | GitHub |
|----------|-------|--------|
| Syntax errors | 0 | 0 (lint-compile) |
| Data tests PASS | 6/6 | 6/6 |
| CSV rows | 633 | 633 |
| Artifact size | ~125K (preview) | ~125K (full export) |
| Export time | ~2-3s | ~45s |
| Total pipeline | ~3 min | ~5-8 min |

---

## 🚨 Troubleshooting

### Local : Modèles ne s'exécutent pas
```powershell
# Vérifier la connexion Snowflake
dbt debug --target dev_password

# Vérifier le .sql syntax
dbt parse --select fct_export_unifie
```

### GitHub : Build failure
```
Action: Voir les logs détaillés dans Actions tab
Cause courante: Changement de schéma Snowflake ou permissions
Fix: Vérifier DBT_PROFILES_DIR + secrets configurés
```

### GitHub : CSV vide ou incomplet
```
Cause: Requête dbt show trop restrictive ou pas de data
Fix: Augmenter --limit 2000000
Vérifier: SELECT * FROM RAW_DATA.fct_export_unifie en Snowflake
```
