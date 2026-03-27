# Configuration Power BI + Power Automate

## 1️⃣ Créer un Power Automate Flow

### Étapes dans Power Automate :

1. Aller sur [https://make.powerautomate.com](https://make.powerautomate.com)
2. **Créer → Cloud flow → Flux cloud instantané**
3. **Trigger (Déclencheur)** : "Quand une requête HTTP est reçue"
   - Cliquer sur **Utiliser un schéma JSON brut**
   - Coller ce schéma :
   ```json
   {
     "type": "object",
     "properties": {
       "exportName": { "type": "string" },
       "exportDate": { "type": "string", "format": "date-time" },
       "rowCount": { "type": "integer" },
       "fileSize": { "type": "string" },
       "status": { "type": "string" },
       "githubArtifact": { "type": "string" },
       "branch": { "type": "string" },
       "commit": { "type": "string" },
       "actor": { "type": "string" }
     }
   }
   ```
   - **Copier l'URL du webhook** généré (format: `https://prod-XX.westeurope.logic.azure.com/...`)

---

## 2️⃣ Ajouter une action "Rafraîchir un dataset Power BI"

1. **Nouvelle étape → Ajouter une action**
2. Chercher : **"Power BI"**
3. Sélectionner : **"Rafraîchir un dataset (attendre la fin)"** (ou "Refresh dataset")

4. **Configurer l'action** :
   - **Workspace** : Sélectionner votre workspace Power BI
   - **Dataset** : Sélectionner le dataset correspondant à `fct_export_unifie`

---

## 3️⃣ Ajouter une notification (optionnel)

### Option A: Notification Teams
1. **Nouvelle étape → Ajouter une action**
2. Chercher : **"Teams"** → **"Publier un message"**
3. **Configurer** :
   ```
   Canal: #data-reports
   Message:
   📊 **Nouvel export DBT complété**
   - Export: @{triggerBody()?['exportName']}
   - Lignes: @{triggerBody()?['rowCount']}
   - Taille: @{triggerBody()?['fileSize']}
   - Date: @{triggerBody()?['exportDate']}
   - Actor: @{triggerBody()?['actor']}
   ```

### Option B: Notification Slack
1. **Nouvelle étape → Ajouter une action**
2. Chercher : **"Slack"** → **"Publier un message"**
3. **Configurer** :
   ```
   Canal: #data-notifications
   Texte du message:
   :bar_chart: DBT Export Complete - @{triggerBody()?['exportName']}
   Rows: @{triggerBody()?['rowCount']} | Size: @{triggerBody()?['fileSize']}
   ```

---

## 4️⃣ Configurer le Secret GitHub

1. Aller dans votre repo GitHub
2. **Settings → Secrets and variables → Actions**
3. **New repository secret** :
   - **Name** : `POWER_AUTOMATE_WEBHOOK_URL`
   - **Value** : Coller l'URL copiée à l'étape 1️⃣

💾 **Sauvegarder le flow** et **tester** (bouton Test en haut à droite)

---

## 5️⃣ Flux d'exécution end-to-end

```
GitHub Actions (dbt-ci.yml)
    ↓
✅ dbt build réussi
    ↓
✅ Export CSV (fct_export_unifie)
    ↓
🔔 Webhook → Power Automate
    ↓
📊 Power BI dataset refresh
    ↓
📢 Notification Teams/Slack (optionnel)
    ↓
✨ Rapports Power BI à jour
```

---

## 🧪 Test manuel

Pour tester le webhook sans passer par GitHub :

```powershell
$url = "https://votre-power-automate-url"
$body = @{
    exportName = "fct_export_unifie_test"
    exportDate = (Get-Date -u -Format "o")
    rowCount = 633
    fileSize = "125K"
    status = "completed"
    githubArtifact = "https://github.com/..."
    branch = "main"
    commit = "abc123"
    actor = "test-user"
} | ConvertTo-Json

Invoke-WebRequest -Uri $url -Method POST -Body $body -ContentType "application/json"
```

---

## 🔐 Authentification Power BI

Si le dataset est dans un **workspace partagé**, vérifier que votre compte a les permissions:
- ✅ Workspace : Mode d'accès = **Contributeur** ou **Admin**
- ✅ Dataset : Permissions de **refresh**

Si blocage d'authentification, créer une **Service Principal** :
1. Azure Portal → App registrations → Nouvelle application
2. Ajouter permission : `Dataset.ReadWrite.All`
3. Utiliser le **Service Principal** dans le Power Automate flow

---

## 📋 Checklist

- [ ] Power Automate flow créé
- [ ] URL webhook copiée
- [ ] Secret `POWER_AUTOMATE_WEBHOOK_URL` ajouté à GitHub
- [ ] Dataset Power BI configuré dans le flow
- [ ] Webhook testé manuellement
- [ ] Pipeline dbt-ci.yml déclenché (push ou workflow_dispatch)
- [ ] ✨ Rafraîchissement Power BI automatique confirmé
