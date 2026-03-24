<#
.SYNOPSIS
    Exporte les tables marts définitives vers des fichiers CSV dans exports/
.DESCRIPTION
    Pour chaque modèle mart, exécute :
      1. dbt run --select <model>  -> matérialise la table dans Snowflake
      2. dbt show -q --select <model> --output csv --limit 2000000 -> exporte le CSV
    Les fichiers sont écrits dans ../exports/ (relatif au projet dbt).
.NOTES
    Prérequis : variables d'environnement Snowflake chargées (load-env.ps1)
    Profile cible : dev_password (authentification par mot de passe, compatible CI)
#>

param(
    [string]$ProfilesDir = $HOME + "\.dbt",
    [string]$ExportsDir  = "..\exports",
    [int]$Limit          = 2000000
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$dbt = Join-Path (Split-Path $ScriptDir -Parent) ".venv\Scripts\dbt.exe"

# Vérification de l'exécutable dbt
if (-not (Test-Path $dbt)) {
    $dbt = "dbt"   # fallback : dbt dans le PATH
}

# Résolution du dossier exports/
$ExportsPath = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir $ExportsDir))
if (-not (Test-Path $ExportsPath)) {
    New-Item -ItemType Directory -Path $ExportsPath | Out-Null
}

$model   = "fct_export_unifie"
$outFile = Join-Path $ExportsPath "$model.csv"

Write-Host "`n=== Export du mart unifié vers CSV ===" -ForegroundColor Cyan
Write-Host "Modèle  : $model"
Write-Host "Fichier : $outFile"
Write-Host ""

# ── 1. Build du mart unifié (run + test) ──────────────────────────────────────
Write-Host "▶ dbt build --select $model" -ForegroundColor Yellow
& $dbt build `
    --project-dir $ScriptDir `
    --profiles-dir $ProfilesDir `
    --target dev_password `
    --select $model `
    --no-use-colors 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "dbt build a échoué (code $LASTEXITCODE). Vérifiez la connexion Snowflake."
    exit 1
}

Write-Host ""

# ── 2. Export en CSV via dbt show ─────────────────────────────────────────────
Write-Host "▶ Export CSV  →  $outFile" -ForegroundColor Yellow

& $dbt show `
    --project-dir $ScriptDir `
    --profiles-dir $ProfilesDir `
    --target dev_password `
    --quiet `
    --select $model `
    --output csv `
    --limit $Limit 2>&1 `
    | Where-Object { $_ -notmatch "^Running with dbt|^Found |^Concurrency|^$" } `
    | Out-File -FilePath $outFile -Encoding utf8

if ($LASTEXITCODE -ne 0) {
    Write-Error "Erreur lors de l'export du modèle $model."
    exit 1
}

$rows = (Import-Csv $outFile).Count
Write-Host "   ✓ $rows lignes exportées" -ForegroundColor Green

Write-Host ""
Write-Host "=== Export terminé ===" -ForegroundColor Cyan
Write-Host ""
Get-Item $outFile | Format-Table Name, Length -AutoSize
