@echo off
setlocal

set SCRIPT_DIR=%~dp0

echo [1/4] Deploy Main Infrastructure...
call "%SCRIPT_DIR%DeployMain.bat"
if errorlevel 1 goto :error

echo [2/4] Deploy Function App Code...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%DeployFunctions.ps1"
if errorlevel 1 goto :error

echo [3/4] Upload APIM Policy...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%UploadPolicy.ps1"
if errorlevel 1 goto :error

echo [4/4] Deploy Frontend App...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%DeployApp.ps1"
if errorlevel 1 goto :error

echo All deployments completed successfully!
exit /b 0

:error
echo Deployment failed!
exit /b 1
