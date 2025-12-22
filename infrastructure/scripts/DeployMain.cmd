@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SUBSCRIPTION_ID="
set "RESOURCE_GROUP=moccgroup"
set "LOCATION=italynorth"
set "WHATIF=false"
set "PAUSE_ON_ERROR=true"

set "SCRIPT_DIR=%~dp0"

:: [1] Root Deployment Files
for %%i in ("%SCRIPT_DIR%..\main.bicep") do set "BICEP_1=%%~fi"
for %%i in ("%SCRIPT_DIR%..\main.bicepparam") do set "PARAM_1=%%~fi"

:: [2] Static Web Module Files
for %%i in ("%SCRIPT_DIR%..\modules\compute\staticweb\main.bicep") do set "BICEP_2=%%~fi"
for %%i in ("%SCRIPT_DIR%..\modules\compute\staticweb\main.bicepparam") do set "PARAM_2=%%~fi"

:: [3] Budget Module Files (NEW)
for %%i in ("%SCRIPT_DIR%..\modules\budget\budget.bicep") do set "BICEP_3=%%~fi"
for %%i in ("%SCRIPT_DIR%..\modules\budget\budget.bicepparam") do set "PARAM_3=%%~fi"


for /f %%i in ('powershell -NoProfile -Command "(Get-Date).ToString(\"yyyyMMdd-HHmmss\")"') do set "TS=%%i"

echo [1/6] Azure CLI
where az >nul 2>&1
if errorlevel 1 call :Fail "Azure CLI not found. Install it and re-run."

echo [2/6] Azure context
call az account show -o table
if errorlevel 1 call :Fail "Azure context unavailable. Run: az login"

if not "%SUBSCRIPTION_ID%"=="" (
  echo - Setting subscription: %SUBSCRIPTION_ID%
  call az account set --subscription "%SUBSCRIPTION_ID%"
  if errorlevel 1 call :Fail "Cannot set subscription '%SUBSCRIPTION_ID%'."
)

for /f "delims=" %%i in ('az account show --query id -o tsv 2^>nul') do set "ACTIVE_SUB=%%i"
if "%ACTIVE_SUB%"=="" call :Fail "No active subscription in current context."

echo - Active subscription id: %ACTIVE_SUB%

echo [3/6] ARM token preflight
for /f "delims=" %%e in ('az account get-access-token --resource https://management.azure.com/ --query expiresOn -o tsv 2^>nul') do set "ARM_EXPIRES=%%e"
if "%ARM_EXPIRES%"=="" (
  echo - Token preflight failed. Details:
  call az account get-access-token --resource https://management.azure.com/
  call :Fail "Unable to get ARM token. Run: az login"
)
echo - ARM token expires on: %ARM_EXPIRES%

echo [4/6] Deploy root
call :Deploy "root" "%BICEP_1%" "%PARAM_1%" "resourceGroup"
for %%i in ("%SCRIPT_DIR%..\modules\identity\aad.bicep") do set "BICEP_4=%%~fi"
if errorlevel 1 exit /b %errorlevel%

echo [5/6] Deploy staticweb
call :Deploy "staticweb" "%BICEP_2%" "%PARAM_2%" "resourceGroup"
if errorlevel 1 exit /b %errorlevel%

echo [6/6] Deploy budget
:: Scope set to "subscription" as requested
call :Deploy "budget" "%BICEP_3%" "%PARAM_3%" "subscription"
if errorlevel 1 exit /b %errorlevel%

echo [7/7] Deploy Identity
call :Deploy "identity" "%BICEP_4%" "%PARAM_1%" "resourceGroup"
if errorlevel 1 exit /b %errorlevel%

echo Done
exit /b 0

:Deploy
set "LABEL=%~1"
set "BICEP=%~2"
set "PARAM=%~3"
set "SCOPE=%~4"
set "DEPLOYMENT_NAME=mocc-%LABEL%-%TS%"

echo - [%LABEL%] Checking files...
if not exist "%BICEP%" call :Fail "Not found: %BICEP%"

if not exist "%PARAM%" (
  if /i "%LABEL%"=="staticweb" (
    echo   WARNING: Param file not found: %PARAM%
    echo   WARNING: Reusing root params: %PARAM_1%
    set "PARAM=%PARAM_1%"
    if not exist "!PARAM!" call :Fail "Not found: !PARAM!"
  ) else (
    call :Fail "Not found: %PARAM%"
  )
)

set "IS_BICEP_PARAM=false"
if /i "%PARAM:~-11%"==".bicepparam" set "IS_BICEP_PARAM=true"

if /i "%SCOPE%"=="subscription" (
  echo - [%LABEL%] scope=subscription name=%DEPLOYMENT_NAME%
  
  if /i "!IS_BICEP_PARAM!"=="true" (
      call az deployment sub create ^
        --location "%LOCATION%" ^
        --name "%DEPLOYMENT_NAME%" ^
        --parameters "%PARAM%"
  ) else (
      call az deployment sub create ^
        --location "%LOCATION%" ^
        --name "%DEPLOYMENT_NAME%" ^
        --template-file "%BICEP%" ^
        --parameters "@%PARAM%"
  )
  if !errorlevel! neq 0 call :Fail "Deployment failed: %LABEL% (subscription scope)."

) else (
  echo - [%LABEL%] scope=resourceGroup rg=%RESOURCE_GROUP% name=%DEPLOYMENT_NAME%
  
  call az group create --name "%RESOURCE_GROUP%" --location "%LOCATION%" -o table
  if !errorlevel! neq 0 call :Fail "Unable to create/access RG: %RESOURCE_GROUP%."

  if /i "%WHATIF%"=="true" (
      if /i "!IS_BICEP_PARAM!"=="true" (
        call az deployment group what-if ^
          --resource-group "%RESOURCE_GROUP%" ^
          --name "%DEPLOYMENT_NAME%" ^
          --parameters "%PARAM%"
      ) else (
        call az deployment group what-if ^
          --resource-group "%RESOURCE_GROUP%" ^
          --name "%DEPLOYMENT_NAME%" ^
          --template-file "%BICEP%" ^
          --parameters "@%PARAM%"
      )
  ) else (
      if /i "!IS_BICEP_PARAM!"=="true" (
        call az deployment group create ^
          --resource-group "%RESOURCE_GROUP%" ^
          --name "%DEPLOYMENT_NAME%" ^
          --parameters "%PARAM%"
      ) else (
        call az deployment group create ^
          --resource-group "%RESOURCE_GROUP%" ^
          --name "%DEPLOYMENT_NAME%" ^
          --template-file "%BICEP%" ^
          --parameters "@%PARAM%"
      )
  )
  if !errorlevel! neq 0 call :Fail "Deployment failed: %LABEL% (resource group scope)."
)

echo - [%LABEL%] OK
goto :eof

:Fail
echo.
echo ERROR: %~1
echo.
if /i "%PAUSE_ON_ERROR%"=="true" pause
exit /b 1