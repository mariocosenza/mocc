@echo off
echo WARNING: You are about to delete ALL Resource Groups in the current subscription.
echo This will wipe all resources permanently.

set /p confirmation="Type 'YES' to proceed: "

if /i not "%confirmation%"=="YES" (
    echo Operation cancelled.
    exit /b
)

for /f "tokens=*" %%g in ('az group list --query "[].name" -o tsv') do (
    echo Deleting Resource Group: %%g
    az group delete --name %%g --yes --no-wait
)

echo All delete requests have been submitted to Azure.
pause