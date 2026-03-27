# Load .env file from the script directory so it works from any current path.
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $scriptRoot ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim() -replace '^\"|\"$'
            [Environment]::SetEnvironmentVariable($key, $value, 'Process')
            Write-Host "Loaded: $key"
        }
    }

    # Ensure project virtualenv binaries are available in this shell session.
    $venvScripts = Join-Path $scriptRoot ".venv\Scripts"
    if (Test-Path $venvScripts) {
        $currentPath = [Environment]::GetEnvironmentVariable('Path', 'Process')
        if (-not ($currentPath -split ';' | Where-Object { $_ -eq $venvScripts })) {
            [Environment]::SetEnvironmentVariable('Path', "$venvScripts;$currentPath", 'Process')
            Write-Host "Loaded default: PATH includes .venv/Scripts"
        }
    }

    if (-not [Environment]::GetEnvironmentVariable('DBT_TARGET', 'Process')) {
        [Environment]::SetEnvironmentVariable('DBT_TARGET', 'dev_password', 'Process')
        Write-Host "Loaded default: DBT_TARGET=dev_password"
    }

    # dbt profile may require this env var even for standard username/password auth.
    if (-not [Environment]::GetEnvironmentVariable('SNOWFLAKE_AUTHENTICATOR', 'Process')) {
        [Environment]::SetEnvironmentVariable('SNOWFLAKE_AUTHENTICATOR', 'snowflake', 'Process')
        Write-Host "Loaded default: SNOWFLAKE_AUTHENTICATOR=snowflake"
    }

    Write-Host "Environment variables loaded successfully!"
} else {
    Write-Host "ERROR: .env file not found!"
    exit 1
}
