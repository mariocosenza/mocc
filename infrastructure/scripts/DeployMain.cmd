@echo off
setlocal enabledelayedexpansion

set "SUBSCRIPTION_ID=YOUR_SUBSCRIPTION_ID"
set "RESOURCE_GROUP=YOUR_RESOURCE_GROUP"
set "LOCATION=italynorth"
set "WHATIF=false"

set "SCRIPT_DIR=%~dp0"

set "BICEP_1=%SCRIPT_DIR%..\main.bicep"
set "PARAM_1=%SCRIPT_DIR%..\main.bicepparam"

set "BICEP_2=%SCRIPT_DIR%..\modules\compute\staticweb\main.bicep"
set "PARAM_2=%SCRIPT_DIR%..\modules\compute\staticweb\main.bicepparam"

az account set --subscription "%SUBSCRIPTION_ID%"
if errorlevel 1 (
  echo ERROR: az account set failed. Run: az login
  exit /b 1
)

for /f %%i in ('powershell -NoProfile -Command "(Get-Date).ToString(\"yyyyMMdd-HHmmss\")"') do set "TS=%%i"

call :Deploy "main" "%BICEP_1%" "%PARAM_1%" || exit /b 1
call :Deploy "staticweb" "%BICEP_2%" "%PARAM_2%" || exit /b 1

exit /b 0

:Deploy
set "LABEL=%~1"
set "BICEP=%~2"
set "PARAM=%~3"
set "DEPLOYMENT_NAME=mocc-%LABEL%-%TS%"

if not exist "%BICEP%" (
  echo ERROR: Not found: "%BICEP%"
  exit /b 1
)

if not exist "%PARAM%" (
  echo ERROR: Not found: "%PARAM%"
  exit /b 1
)

set "IS_SUB=false"
findstr /C:"targetScope = 'subscription'" "%BICEP%" >nul 2>&1 && set "IS_SUB=true"

if /i "!IS_SUB!"=="true" (
  if /i "%WHATIF%"=="true" (
    az deployment sub what-if ^
      --location "%LOCATION%" ^
      --name "%DEPLOYMENT_NAME%" ^
      --template-file "%BICEP%" ^
      --parameters @"%PARAM%"
    exit /b !errorlevel!
  ) else (
    az deployment sub create ^
      --location "%LOCATION%" ^
      --name "%DEPLOYMENT_NAME%" ^
      --template-file "%BICEP%" ^
      --parameters @"%PARAM%"
    exit /b !errorlevel!
  )
) else (
  az group create --name "%RESOURCE_GROUP%" --location "%LOCATION%" 1>nul
  if errorlevel 1 (
    echo ERROR: Unable to create/access RG: "%RESOURCE_GROUP%"
    exit /b 1
  )

  if /i "%WHATIF%"=="true" (
    az deployment group what-if ^
      --resource-group "%RESOURCE_GROUP%" ^
      --name "%DEPLOYMENT_NAME%" ^
      --template-file "%BICEP%" ^
      --parameters @"%PARAM%"
    exit /b !errorlevel!
  ) else (
    az deployment group create ^
      --resource-group "%RESOURCE_GROUP%" ^
      --name "%DEPLOYMENT_NAME%" ^
      --template-file "%BICEP%" ^
      --parameters @"%PARAM%"
    exit /b !errorlevel!
  )
)
