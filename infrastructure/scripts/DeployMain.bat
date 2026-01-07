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
for %%i in ("%SCRIPT_DIR%..\modules\compute\staticweb\main.bicepparam") do set "PARAM_2=%%~fi"

for %%i in ("%SCRIPT_DIR%..\modules\budget\budget.bicep") do set "BICEP_3=%%~fi"
for %%i in ("%SCRIPT_DIR%..\modules\budget\budget.bicepparam") do set "PARAM_3=%%~fi"

for %%i in ("%SCRIPT_DIR%..\modules\auth\entra.bicep") do set "BICEP_4=%%~fi"

for /f %%i in ('powershell -NoProfile -Command "(Get-Date).ToString(\"yyyyMMdd-HHmmss\")"') do set "TS=%%i"

echo [1/8] Azure CLI
where az >nul 2>&1 || call :Fail "Azure CLI not found."

echo [2/8] Azure context
call az account show -o table || call :Fail "Run: az login"

if not "%SUBSCRIPTION_ID%"=="" (
  call az account set --subscription "%SUBSCRIPTION_ID%" || call :Fail "Cannot set subscription."
)

echo [3/8] ARM token
call az account get-access-token --resource https://management.azure.com/ >nul || call :Fail "ARM token failed."

echo [4/8] Graph token
call az account get-access-token --resource-type ms-graph >nul || call :Fail "Graph token failed."

echo [5/8] Deploy root
call :Deploy "root" "%BICEP_1%" "%PARAM_1%" "resourceGroup" || exit /b 1

echo [6/8] Deploy staticweb
call :Deploy "staticweb" "%BICEP_2%" "%PARAM_2%" "resourceGroup" || exit /b 1

echo [7/8] Deploy budget
call :Deploy "budget" "%BICEP_3%" "%PARAM_3%" "subscription" || exit /b 1

echo [8/8] Deploy entra
call :Deploy "entra" "%BICEP_4%" "" "subscription" || exit /b 1

call :UpdateAcaEnvFromEntra "%LAST_SUB_DEPLOYMENT_NAME%" || exit /b 1

echo Done
exit /b 0


:Deploy
set "LABEL=%~1"
set "BICEP=%~2"
set "PARAM=%~3"
set "SCOPE=%~4"
set "DEPLOYMENT_NAME=mocc-%LABEL%-%TS%"

echo - [%LABEL%] Checking files...
if not exist "%BICEP%" call :Fail "Missing %BICEP%"

if not "%PARAM%"=="" (
  if not exist "%PARAM%" (
    if /i "%LABEL%"=="staticweb" (
      echo   WARNING: Reusing root params
      set "PARAM=%PARAM_1%"
      if not exist "!PARAM!" call :Fail "Missing root params"
    ) else (
      call :Fail "Missing params: %PARAM%"
    )
  )
)

REM --- NEW LOGIC: Build arguments dynamically ---
set "IS_BICEP_PARAM=false"
if not "%PARAM%"=="" (
  if /i "%PARAM:~-11%"==".bicepparam" set "IS_BICEP_PARAM=true"
)

REM Define CMD_ARGS based on whether parameters are present or not
if /i "%IS_BICEP_PARAM%"=="true" (
    REM Case A: .bicepparam file (No template file needed usually)
    set "CMD_ARGS=--parameters "%PARAM%""
) else (
    if "%PARAM%"=="" (
        REM Case B: Standard Bicep file with NO parameters (Fixes Step 8)
        set "CMD_ARGS=--template-file "%BICEP%""
    ) else (
        REM Case C: Standard Bicep file WITH parameters
        set "CMD_ARGS=--template-file "%BICEP%" --parameters "@%PARAM%""
    )
)
REM ---------------------------------------------

if /i "%SCOPE%"=="subscription" (
  echo - [%LABEL%] scope=subscription name=%DEPLOYMENT_NAME%

  call az deployment sub create ^
    --location "%LOCATION%" ^
    --name "%DEPLOYMENT_NAME%" ^
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
