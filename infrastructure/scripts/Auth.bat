@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ==============================
rem CONFIG
rem ==============================
set "LOCATION=italynorth"
set "WHATIF=false"
set "PAUSE_ON_ERROR=true"

rem Optional: set this to force the right tenant
rem set "TENANT_ID=<your-tenant-guid>"

set "SCRIPT_DIR=%~dp0"

for %%i in ("%SCRIPT_DIR%..\modules\auth\entra.bicep") do set "BICEP=%%~fi"
for %%i in ("%SCRIPT_DIR%..\modules\auth\entra.bicepparam") do set "PARAM=%%~fi"

for /f %%i in ('powershell -NoProfile -Command "(Get-Date).ToString(\"yyyyMMdd-HHmmss\")"') do set "TS=%%i"
set "DEPLOYMENT_NAME=mocc-entra-%TS%"

echo [1/4] Azure CLI
where az >nul 2>&1
if errorlevel 1 call :Fail "Azure CLI not found. Install it and re-run."

echo [2/4] Azure context
call az account show -o table
if errorlevel 1 call :Fail "Azure context unavailable. Run: az login"

if not "%TENANT_ID%"=="" (
  echo - Switching tenant: %TENANT_ID%
  call az login --tenant "%TENANT_ID%" >nul
  if errorlevel 1 call :Fail "Cannot login to tenant '%TENANT_ID%'."
)

echo [3/4] Token preflight (ARM + Graph)
for /f "delims=" %%e in ('az account get-access-token --resource https://management.azure.com/ --query expiresOn -o tsv 2^>nul') do set "ARM_EXPIRES=%%e"
if "%ARM_EXPIRES%"=="" (
  call az account get-access-token --resource https://management.azure.com/
  call :Fail "Unable to get ARM token. Run: az login"
)
echo - ARM token expires on: %ARM_EXPIRES%

for /f "delims=" %%g in ('az account get-access-token --resource-type ms-graph --query expiresOn -o tsv 2^>nul') do set "GRAPH_EXPIRES=%%g"
if "%GRAPH_EXPIRES%"=="" (
  call az account get-access-token --resource-type ms-graph
  call :Fail "Unable to get Microsoft Graph token."
)
echo - Graph token expires on: %GRAPH_EXPIRES%

echo [4/4] Deploy entra (SUBSCRIPTION)
echo - Checking files...
if not exist "%BICEP%" call :Fail "Not found: %BICEP%"

set "USE_PARAM=false"
if exist "%PARAM%" set "USE_PARAM=true"

echo - scope=subscription name=%DEPLOYMENT_NAME%
if /i "%WHATIF%"=="true" (
  if /i "%USE_PARAM%"=="true" (
    call az deployment sub what-if ^
      --location "%LOCATION%" ^
      --name "%DEPLOYMENT_NAME%" ^
      --parameters "%PARAM%"
  ) else (
    call az deployment sub what-if ^
      --location "%LOCATION%" ^
      --name "%DEPLOYMENT_NAME%" ^
      --template-file "%BICEP%"
  )
) else (
  if /i "%USE_PARAM%"=="true" (
    call az deployment sub create ^
      --location "%LOCATION%" ^
      --name "%DEPLOYMENT_NAME%" ^
      --parameters "%PARAM%"
  ) else (
    call az deployment sub create ^
      --location "%LOCATION%" ^
      --name "%DEPLOYMENT_NAME%" ^
      --template-file "%BICEP%"
  )
)

if errorlevel 1 call :Fail "Entra deployment failed (subscription scope)."

echo.
echo OK: Entra deployed at subscription scope.
echo Deployment name: %DEPLOYMENT_NAME%
exit /b 0


:Fail
echo.
echo ERROR: %~1
echo.
if /i "%PAUSE_ON_ERROR%"=="true" pause
exit /b 1
