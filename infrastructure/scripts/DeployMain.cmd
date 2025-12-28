@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SUBSCRIPTION_ID=%SUBSCRIPTION_ID%"
set "RESOURCE_GROUP=moccgroup"
set "LOCATION=westeurope"
set "WHATIF=false"
set "PAUSE_ON_ERROR=true"

set "SCRIPT_DIR=%~dp0"

:: [1] Root Deployment Files
for %%i in ("%SCRIPT_DIR%..\main.bicep") do set "BICEP_1=%%~fi"
for %%i in ("%SCRIPT_DIR%..\main.bicepparam") do set "PARAM_1=%%~fi"

:: [2] Static Web Module Files
for %%i in ("%SCRIPT_DIR%..\modules\compute\staticweb\main.bicep") do set "BICEP_2=%%~fi"
for %%i in ("%SCRIPT_DIR%..\modules\compute\staticweb\main.bicepparam") do set "PARAM_2=%%~fi"

:: [3] Budget Module Files
for %%i in ("%SCRIPT_DIR%..\modules\budget\budget.bicep") do set "BICEP_3=%%~fi"
for %%i in ("%SCRIPT_DIR%..\modules\budget\budget.bicepparam") do set "PARAM_3=%%~fi"

:: [4] Entra (Tenant) Module Files (NEW)
for %%i in ("%SCRIPT_DIR%..\modules\auth\entra.bicep") do set "BICEP_4=%%~fi"
:: Optional: if you create a param file for entra
for %%i in ("%SCRIPT_DIR%..\modules\auth\entra.bicepparam") do set "PARAM_4=%%~fi"

for /f %%i in ('powershell -NoProfile -Command "(Get-Date).ToString(\"yyyyMMdd-HHmmss\")"') do set "TS=%%i"

echo [1/7] Azure CLI
where az >nul 2>&1
if errorlevel 1 call :Fail "Azure CLI not found. Install it and re-run."

echo [2/7] Azure context
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

echo [3/7] ARM token preflight
for /f "delims=" %%e in ('az account get-access-token --resource https://management.azure.com/ --query expiresOn -o tsv 2^>nul') do set "ARM_EXPIRES=%%e"
if "%ARM_EXPIRES%"=="" (
  echo - Token preflight failed. Details:
  call az account get-access-token --resource https://management.azure.com/
  call :Fail "Unable to get ARM token. Run: az login"
)
echo - ARM token expires on: %ARM_EXPIRES%

echo [4/7] Microsoft Graph token preflight (recommended for Entra app registration via Graph)
for /f "delims=" %%g in ('az account get-access-token --resource-type ms-graph --query expiresOn -o tsv 2^>nul') do set "GRAPH_EXPIRES=%%g"
if "%GRAPH_EXPIRES%"=="" (
  echo - Graph token preflight failed. Details:
  call az account get-access-token --resource-type ms-graph
  call :Fail "Unable to get Microsoft Graph token. Ensure you are logged in and have Graph permissions for the deploying identity."
)
echo - Graph token expires on: %GRAPH_EXPIRES%

echo [5/7] Deploy root
call :Deploy "root" "%BICEP_1%" "%PARAM_1%" "resourceGroup"
if errorlevel 1 exit /b %errorlevel%

echo [6/7] Deploy staticweb
call :Deploy "staticweb" "%BICEP_2%" "%PARAM_2%" "resourceGroup"
if errorlevel 1 exit /b %errorlevel%

echo [7/7] Deploy budget
call :Deploy "budget" "%BICEP_3%" "%PARAM_3%" "subscription"
if errorlevel 1 exit /b %errorlevel%

:: Optional: deploy Entra after infra (or move earlier if you want the clientId output for other deployments)
echo [EXTRA] Deploy entra (tenant)
:: If you have entra.bicepparam, pass it. If not, pass "" and it will be treated as missing/ignored.
if exist "%PARAM_4%" (
  call :Deploy "entra" "%BICEP_4%" "%PARAM_4%" "tenant"
) else (
  call :Deploy "entra" "%BICEP_4%" "" "tenant"
)
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

:: PARAM is optional for tenant deployments in this script (you can still use it if present)
if not "%PARAM%"=="" (
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
)

set "IS_BICEP_PARAM=false"
if not "%PARAM%"=="" (
  if /i "%PARAM:~-11%"==".bicepparam" set "IS_BICEP_PARAM=true"
)

if /i "%SCOPE%"=="tenant" (
  echo - [%LABEL%] scope=tenant name=%DEPLOYMENT_NAME%

  if /i "%WHATIF%"=="true" (
    if not "%PARAM%"=="" (
      if /i "!IS_BICEP_PARAM!"=="true" (
        call az deployment tenant what-if ^
          --location "%LOCATION%" ^
          --name "%DEPLOYMENT_NAME%" ^
          --parameters "%PARAM%"
      ) else (
        call az deployment tenant what-if ^
          --location "%LOCATION%" ^
          --name "%DEPLOYMENT_NAME%" ^
          --template-file "%BICEP%" ^
          --parameters "@%PARAM%"
      )
    ) else (
      call az deployment tenant what-if ^
        --location "%LOCATION%" ^
        --name "%DEPLOYMENT_NAME%" ^
        --template-file "%BICEP%"
    )
  ) else (
    if not "%PARAM%"=="" (
      if /i "!IS_BICEP_PARAM!"=="true" (
        call az deployment tenant create ^
          --location "%LOCATION%" ^
          --name "%DEPLOYMENT_NAME%" ^
          --parameters "%PARAM%"
      ) else (
        call az deployment tenant create ^
          --location "%LOCATION%" ^
          --name "%DEPLOYMENT_NAME%" ^
          --template-file "%BICEP%" ^
          --parameters "@%PARAM%"
      )
    ) else (
      call az deployment tenant create ^
        --location "%LOCATION%" ^
        --name "%DEPLOYMENT_NAME%" ^
        --template-file "%BICEP%"
    )
  )

  if !errorlevel! neq 0 call :Fail "Deployment failed: %LABEL% (tenant scope)."

) else if /i "%SCOPE%"=="subscription" (
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
