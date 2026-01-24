@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SUBSCRIPTION_ID=%SUBSCRIPTION_ID%"
set "RESOURCE_GROUP=moccgroup"
set "LOCATION=italynorth"
set "WHATIF=false"
set "PAUSE_ON_ERROR=true"

set "ACA_NAME=mocc-aca"
set "COSMOS_DATABASE=mocc-db"

set "SCRIPT_DIR=%~dp0"

for %%i in ("%SCRIPT_DIR%..\main.bicep") do set "BICEP_1=%%~fi"
for %%i in ("%SCRIPT_DIR%..\main.bicepparam") do set "PARAM_1=%%~fi"

for %%i in ("%SCRIPT_DIR%..\modules\compute\staticweb\main.bicep") do set "BICEP_2=%%~fi"

for %%i in ("%SCRIPT_DIR%..\modules\budget\budget.bicep") do set "BICEP_3=%%~fi"
for %%i in ("%SCRIPT_DIR%..\modules\budget\budget.bicepparam") do set "PARAM_3=%%~fi"

for %%i in ("%SCRIPT_DIR%..\modules\auth\entra.bicep") do set "BICEP_4=%%~fi"

for /f %%i in ('powershell -NoProfile -Command "(Get-Date).ToString(\"yyyyMMdd-HHmmss\")"') do set "TS=%%i"

echo [1/9] Azure CLI
where az >nul 2>&1 || call :Fail "Azure CLI not found."

echo [2/9] Azure context
call az account show -o table >nul 2>&1 || call :Fail "Run: az login"

if not "%SUBSCRIPTION_ID%"=="" (
  call az account set --subscription "%SUBSCRIPTION_ID%" || call :Fail "Cannot set subscription."
)

echo [3/9] ARM token
call az account get-access-token --resource https://management.azure.com/ >nul || call :Fail "ARM token failed."

echo [4/9] Graph token
call az account get-access-token --resource-type ms-graph >nul || call :Fail "Graph token failed."

echo [4/9] Graph token
call az account get-access-token --resource-type ms-graph >nul || call :Fail "Graph token failed."

echo [5/9] Deploy entra (First, to get IDs)
call :Deploy "entra" "%BICEP_4%" "" "subscription" || exit /b 1
for /f "delims=" %%i in ('az deployment sub show --name "%LAST_SUB_DEPLOYMENT_NAME%" --query "properties.outputs.backendClientId.value" -o tsv') do set "BACKEND_CLIENT_ID=%%i"
echo   - Backend Client ID: %BACKEND_CLIENT_ID%

echo [6/9] Deploy root
call :Deploy "root" "%BICEP_1%" "%PARAM_1%" "resourceGroup" "-p backendClientId=%BACKEND_CLIENT_ID%" || exit /b 1

echo [7/9] Deploy staticweb (uses root params)
call :Deploy "staticweb" "%BICEP_2%" "%PARAM_1%" "resourceGroup" "-p location=westeurope" || exit /b 1

echo [8/9] Deploy budget
call :Deploy "budget" "%BICEP_3%" "%PARAM_3%" "subscription" || exit /b 1

echo [9/9] Update ACA env from Entra outputs
call :UpdateAcaEnvFromEntra "%LAST_SUB_DEPLOYMENT_NAME%" || exit /b 1

echo Done
exit /b 0


:Deploy
set "LABEL=%~1"
set "BICEP=%~2"
set "PARAM=%~3"
set "SCOPE=%~4"
set "EXTRA_ARGS=%~5"
set "DEPLOYMENT_NAME=mocc-%LABEL%-%TS%"

echo - [%LABEL%] Checking files...
if not exist "%BICEP%" call :Fail "Missing template: %BICEP%"

if not "%PARAM%"=="" (
  if not exist "%PARAM%" call :Fail "Missing params: %PARAM%"
)

set "IS_BICEP_PARAM=false"
if not "%PARAM%"=="" (
  if /i "%PARAM:~-11%"==".bicepparam" set "IS_BICEP_PARAM=true"
)

set "CMD_ARGS="
if /i "%IS_BICEP_PARAM%"=="true" (
  set "CMD_ARGS=--parameters ""%PARAM%"""
) else (
  if "%PARAM%"=="" (
    set "CMD_ARGS=--template-file ""%BICEP%"" %EXTRA_ARGS%"
  ) else (
    set "CMD_ARGS=--template-file ""%BICEP%"" --parameters ""@%PARAM%"" %EXTRA_ARGS%"
  )
)

set "WHATIF_ARGS="
if /i "%WHATIF%"=="true" set "WHATIF_ARGS=--what-if"

if /i "%SCOPE%"=="subscription" (
  echo - [%LABEL%] scope=subscription name=%DEPLOYMENT_NAME%

  call az deployment sub create ^
    --location "%LOCATION%" ^
    --name "%DEPLOYMENT_NAME%" ^
    %WHATIF_ARGS% ^
    %CMD_ARGS%

  if errorlevel 1 call :Fail "Subscription deployment failed: %LABEL%."
  if /i "%LABEL%"=="entra" set "LAST_SUB_DEPLOYMENT_NAME=%DEPLOYMENT_NAME%"
  goto :eof
)

echo - [%LABEL%] scope=resourceGroup rg=%RESOURCE_GROUP% name=%DEPLOYMENT_NAME%

call az group create --name "%RESOURCE_GROUP%" --location "%LOCATION%" -o none
if errorlevel 1 call :Fail "Failed to create/access RG."

call az deployment group create ^
  --resource-group "%RESOURCE_GROUP%" ^
  --name "%DEPLOYMENT_NAME%" ^
  %WHATIF_ARGS% ^
  %CMD_ARGS%

if errorlevel 1 call :Fail "Resource group deployment failed: %LABEL%."
goto :eof


:UpdateAcaEnvFromEntra
set "DEPLOYMENT=%~1"
if "%DEPLOYMENT%"=="" call :Fail "Missing Entra deployment name."

for /f "delims=" %%i in ('az deployment sub show --name "%DEPLOYMENT%" --query "properties.outputs.tenantId.value" -o tsv') do set "TENANT_ID=%%i"
for /f "delims=" %%i in ('az deployment sub show --name "%DEPLOYMENT%" --query "properties.outputs.expectedAudience.value" -o tsv') do set "EXPECTED_AUDIENCE=%%i"
for /f "delims=" %%i in ('az deployment sub show --name "%DEPLOYMENT%" --query "properties.outputs.requiredScope.value" -o tsv') do set "REQUIRED_SCOPE=%%i"

call az containerapp update ^
  --resource-group "%RESOURCE_GROUP%" ^
  --name "%ACA_NAME%" ^
  --set-env-vars ^
    RUNNING_ON_AZURE=true ^
    TENANT_ID="%TENANT_ID%" ^
    EXPECTED_AUDIENCE="%EXPECTED_AUDIENCE%" ^
    REQUIRED_SCOPE="%REQUIRED_SCOPE%" ^
    COSMOS_DATABASE="%COSMOS_DATABASE%" ^
  -o none || call :Fail "ACA env update failed."

goto :eof


:Fail
echo.
echo ERROR: %~1
if /i "%PAUSE_ON_ERROR%"=="true" pause
exit /b 1
