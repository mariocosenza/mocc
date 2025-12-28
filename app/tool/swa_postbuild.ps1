$ErrorActionPreference = "Stop"

Copy-Item -Force ".\staticwebapp.config.json" ".\build\web\staticwebapp.config.json"
