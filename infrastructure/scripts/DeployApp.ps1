$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$root = (Get-Item (Join-Path $ScriptRoot "..\..")).FullName
$appDir = Join-Path $root "app"

$APP_ID = "1abbe04a-3b9b-4a19-800c-cd8cbbe479f4"
$API_URL = "https://moccapim.azure-api.net/query"
$SWA_NAME = "mocc"

# Clear local storage emulator connection string if present to ensure we target Azure Cloud
if ($env:AZURE_STORAGE_CONNECTION_STRING) {
    $env:AZURE_STORAGE_CONNECTION_STRING = $null
}

# Force Azure CLI to use Entra ID (Login) mode for Storage, as Key-access is disabled
$env:AZURE_STORAGE_AUTH_MODE = "login"

Write-Host "Setting working directory to: $appDir" -ForegroundColor Gray
Push-Location $appDir

try {
    Write-Host "`n1. Building Flutter Web..." -ForegroundColor Cyan
    flutter build web --release `
        --dart-define=RUNNING_ON_AZURE=true `
        --dart-define=AUTH_CLIENT_ID=$APP_ID `
        --dart-define=AUTH_AUTHORITY="https://login.microsoftonline.com/common" `
        --dart-define=AUTH_API_SCOPES="api://mocc-backend-api/access_as_user" `
        --dart-define=MOCC_API_URL="https://moccapim.azure-api.net/query"

    Write-Host "`n2. Injecting Config..." -ForegroundColor Cyan
    if (Test-Path "build\web\config.js") {
        (Get-Content build\web\config.js).Replace('%%MOCC_API_URL%%', $API_URL) | Set-Content build\web\config.js
        Write-Host "Injected API URL into config.js"
    }
    Copy-Item staticwebapp.config.json build\web\staticwebapp.config.json
    Write-Host "Copied staticwebapp.config.json"

    Write-Host "`n3. Deploying to Azure..." -ForegroundColor Cyan

    swa deploy --env production --resource-group moccgroup --location westeurope --api-language 16

    Write-Host "`n4. Updating Entra ID Redirect URIs..." -ForegroundColor Cyan
    $swaUrl = az staticwebapp show --name $SWA_NAME --query "defaultHostname" -o tsv
    if ($null -ne $swaUrl) {
        $fullUrl = "https://$swaUrl/"
        Write-Host "Current SWA URL: $fullUrl"
        
        $appJsonStr = az ad app show --id $APP_ID -o json
        if ($null -eq $appJsonStr) {
            Write-Host "Failed to fetch App Registration. Check permissions/ID." -ForegroundColor Red
            return
        }
        $appJson = $appJsonStr | ConvertFrom-Json
        
        $currentUris = @()
        if ($null -ne $appJson.spa -and $null -ne $appJson.spa.redirectUris) {
            $currentUris = $appJson.spa.redirectUris
        }
        
        Write-Host "Found $($currentUris.Count) existing redirect URIs."

        if ($currentUris -notcontains $fullUrl) {
            $currentUris += $fullUrl
            
            try {
                # Fetch Object ID (Graph API needs Object ID, not App/Client ID)
                $objId = az ad app show --id $APP_ID --query id -o tsv
                
                Write-Host "Updating SPA redirectUris via Graph API (ObjID: $objId)..."
                
                # Construct exact Graph API payload
                $payload = @{
                    spa = @{
                        redirectUris = $currentUris
                    }
                }
                
                # Write to file to ensure cleaner passing to az rest
                $jsonFile = "spa_update_graph.json"
                $payload | ConvertTo-Json -Depth 5 -Compress | Set-Content $jsonFile -Encoding ASCII
                
                # Use az rest to bypass CLI command parsing issues
                az rest --method PATCH `
                    --uri "https://graph.microsoft.com/v1.0/applications/$objId" `
                    --headers "Content-Type=application/json" `
                    --body "@$jsonFile"
                        
                Write-Host "Successfully added $fullUrl to App Registration (SPA)!" -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to update App Registration: $_" -ForegroundColor Red
            }
            finally {
                if (Test-Path $jsonFile) { Remove-Item $jsonFile }
            }
        }
        else {
            Write-Host "URL $fullUrl already registered in Entra ID." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Could not retrieve SWA URL. Make sure you are logged in (az login)." -ForegroundColor Red
    }

    Write-Host "`nDeployment Complete!" -ForegroundColor Green
}
finally {
    Pop-Location
}
