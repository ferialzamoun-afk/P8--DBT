<#
.SYNOPSIS
    Exporte les tables marts définitives vers des fichiers CSV dans exports/
.DESCRIPTION
    Pour chaque modèle mart, exécute :
      1. dbt run --select <model>  -> matérialise la table dans Snowflake
            2. dbt show -q --select <model> --output json --limit 2000000, puis conversion en CSV
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

function Get-DbtShowRows {
    param(
        [Parameter(Mandatory = $true)]
        $Node,
        [int]$Depth = 0
    )

    if ($null -eq $Node -or $Depth -gt 10) {
        return @()
    }

    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        $items = @($Node)
        if ($items.Count -gt 0 -and $items[0] -is [pscustomobject]) {
            return @($items | Where-Object { $_ -is [pscustomobject] })
        }

        foreach ($item in $items) {
            $rows = Get-DbtShowRows -Node $item -Depth ($Depth + 1)
            if ($rows.Count -gt 0) {
                return $rows
            }
        }
        return @()
    }

    if ($Node -is [pscustomobject]) {
        if ($Node.PSObject.Properties['show'] -and $Node.show) {
            $rows = Get-DbtShowRows -Node $Node.show -Depth ($Depth + 1)
            if ($rows.Count -gt 0) {
                return $rows
            }
        }

        $rowsProp = $Node.PSObject.Properties['rows']
        $colsProp = if ($Node.PSObject.Properties['column_names']) { $Node.column_names } elseif ($Node.PSObject.Properties['columns']) { $Node.columns } else { $null }
        if ($rowsProp -and $colsProp) {
            $rawRows = @($rowsProp.Value)
            $rawCols = @($colsProp) | ForEach-Object { @($_) } | ForEach-Object { @($_) }
            if ($rawRows.Count -gt 0 -and ($rawCols | Measure-Object).Count -gt 0) {
                $converted = foreach ($rawRow in $rawRows) {
                    $values = @($rawRow)
                    $obj = [ordered]@{}
                    for ($i = 0; $i -lt $rawCols.Count; $i++) {
                        $obj[$rawCols[$i]] = if ($i -lt $values.Count) { $values[$i] } else { $null }
                    }
                    [pscustomobject]$obj
                }
                return @($converted)
            }
        }

        $dataProp = $Node.PSObject.Properties['data']
        if ($dataProp -and $dataProp.Value -is [System.Collections.IEnumerable]) {
            $dataItems = @($dataProp.Value)
            if ($dataItems.Count -gt 0 -and ($dataItems[0] -is [pscustomobject])) {
                return @($dataItems)
            }
        }

        foreach ($key in @("results", "result", "records", "items")) {
            if ($Node.PSObject.Properties[$key] -and $Node.($key)) {
                $rows = Get-DbtShowRows -Node $Node.($key) -Depth ($Depth + 1)
                if ($rows.Count -gt 0) {
                    return $rows
                }
            }
        }

        foreach ($prop in $Node.PSObject.Properties) {
            if ($prop.Value -is [pscustomobject] -or ($prop.Value -is [System.Collections.IEnumerable] -and -not ($prop.Value -is [string]))) {
                $rows = Get-DbtShowRows -Node $prop.Value -Depth ($Depth + 1)
                if ($rows.Count -gt 0) {
                    return $rows
                }
            }
        }
    }

    return @()
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


Write-Host "[MODIF 2026-03-25] : Export direct CSV sans parsing JSON" -ForegroundColor Green
Write-Host "▶ Export CSV  →  $outFile" -ForegroundColor Yellow

# Utilise dbt show --output csv pour écrire directement le CSV
$showExitCode = 0
& $dbt show `
    --project-dir $ScriptDir `
    --profiles-dir $ProfilesDir `
    --target dev_password `
    --quiet `
    --select $model `
    --output csv `
    --limit $Limit `
    | Out-File -FilePath $outFile -Encoding utf8
$showExitCode = $LASTEXITCODE

if ($showExitCode -ne 0) {
    Write-Error "Erreur lors de l'export du modèle $model en CSV."
    exit 1
}

Write-Host "   OK: $($rows.Count) rows exported" -ForegroundColor Green

Write-Host ""
Write-Host "=== Export complete ===" -ForegroundColor Cyan
Write-Host ""
Get-Item $outFile | Format-Table Name, Length -AutoSize
