$ErrorActionPreference = "Stop"

Write-Host "Resolving Function App Name..." -ForegroundColor Cyan

# Find function app name
$searchName = "mocc-funcs-"
$funcName = az functionapp list --query "[?starts_with(name, '$searchName')].name | [0]" -o tsv

if (-not $funcName) {
    Write-Error "Could not find Function App starting with '$searchName'"
}

Write-Host "Found Function App: $funcName" -ForegroundColor Green

Write-Host "Publishing Function App Code..." -ForegroundColor Cyan

# Check for 'functions' folder relative to script location
$scriptPath = $PSScriptRoot
$funcPath = Join-Path $scriptPath "..\..\functions"

if (-not (Test-Path $funcPath)) {
    Write-Error "Functions directory not found at $funcPath"
}

Push-Location $funcPath
try {
    # Publish using Core Tools
    func azure functionapp publish $funcName --python
}
catch {
    Write-Error "Failed to publish Function App: $_"
}
finally {
    Pop-Location
}

Write-Host "Deployment completed." -ForegroundColor Green
