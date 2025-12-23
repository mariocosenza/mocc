@echo off
setlocal EnableExtensions EnableDelayedExpansion

echo ================================================================
echo WARNING: You are about to delete ALL Resource Groups in:
call az account show --query name -o tsv
echo.
echo This will wipe all resources permanently.
echo Additionally, this script will attempt to PURGE soft-deleted:
echo  - Key Vaults
echo  - API Management (APIM) instances
echo ================================================================
echo.

set /p confirmation="Type 'YES' to proceed: "

if /i not "%confirmation%"=="YES" (
    echo Operation cancelled.
    exit /b
)

REM ----------------------------
REM 1) Delete all Resource Groups
REM ----------------------------
echo.
echo [Step 1/3] Deleting Resource Groups...

for /f "usebackq delims=" %%g in (`az group list --query "[].name" -o tsv 2^>nul`) do (
    echo  - Deleting Resource Group: %%g
    call az group delete --name "%%g" --yes --no-wait
)

echo.
echo Delete requests submitted. 
echo Waiting 60 seconds for resources to transition to 'Soft Deleted' state...
timeout /t 60 /nobreak >nul

REM ------------------------------------------
REM 2) Purge soft-deleted Key Vaults
REM ------------------------------------------
echo.
echo [Step 2/3] Attempting to purge soft-deleted Key Vaults...

REM We join name and location with a semicolon to handle locations with spaces safely
for /f "usebackq tokens=1,2 delims=;" %%k in (`
    az keyvault list-deleted --query "[].join(';', [name, properties.location])" -o tsv 2^>nul
`) do (
    echo  - Purging Key Vault: %%k (Location: %%l)
    call az keyvault purge --name "%%k" --location "%%l" 1>nul 2>nul
    
    if !errorlevel! neq 0 (
        echo    ^> Purge failed for %%k (Check permissions or purge protection).
    ) else (
        echo    ^> Purge submitted for %%k
    )
)

REM ---------------------------------------------------
REM 3) Purge soft-deleted API Management (APIM)
REM ---------------------------------------------------
echo.
echo [Step 3/3] Attempting to purge soft-deleted APIM instances...

REM Query joins name and location with ';' to handle regions like "West Europe"
for /f "usebackq tokens=1,2 delims=;" %%a in (`
    az apim deletedservice list --query "[].join(';', [serviceName || name, location])" -o tsv 2^>nul
`) do (
    echo  - Purging APIM: %%a (Location: %%b)
    call az apim deletedservice purge --service-name "%%a" --location "%%b" 1>nul 2>nul
    
    if !errorlevel! neq 0 (
        echo    ^> Purge failed for %%a (Check permissions or retention).
    ) else (
        echo    ^> Purge submitted for %%a
    )
)

echo.
echo ----------------------------------------------------------------
echo Done. 
echo Note: Resource groups may still be in 'Deleting' state in the background.
echo ----------------------------------------------------------------
pause