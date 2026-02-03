# MOCC - Meal Optimizer Cloud Chef

<p align="center">
  <a href="https://github.com/mariocosenza/mocc/actions/workflows/deploy_backend.yml"><img src="https://img.shields.io/github/actions/workflow/status/mariocosenza/mocc/deploy_backend.yml?style=flat-square&logo=github&label=Backend" /></a>
  <a href="https://github.com/mariocosenza/mocc/actions/workflows/deploy_function.yml"><img src="https://img.shields.io/github/actions/workflow/status/mariocosenza/mocc/deploy_function.yml?style=flat-square&logo=github&label=Functions" /></a>
  <a href="https://github.com/mariocosenza/mocc/actions/workflows/deploy_static.yml"><img src="https://img.shields.io/github/actions/workflow/status/mariocosenza/mocc/deploy_static.yml?style=flat-square&logo=github&label=Web" /></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat-square&logo=Flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Go-%2300ADD8.svg?style=flat-square&logo=go&logoColor=white" />
  <img src="https://img.shields.io/badge/Azure-%230072C6.svg?style=flat-square&logo=microsoftazure&logoColor=white" />
  <img src="https://img.shields.io/badge/python-3670A0?style=flat-square&logo=go&logoColor=white">
</p>

MOCC is a comprehensive inventory and recipe management system built with a Flutter frontend and a Go-based GraphQL backend, leveraging Azure's cloud infrastructure for scalability and reliability.

## 🚀 Deployment

The project is structured to be deployed primarily via automated scripts and Azure Bicep templates.

### Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Node.js](https://nodejs.org/) & [SWA CLI](https://azure.github.io/static-web-apps-cli/)

### 1. Infrastructure Deployment

To deploy the base infrastructure (Azure Container Apps, CosmosDB, API Management, etc.):

1. Open a terminal in the project root.
2. Run the deployment script:
   ```bash
   ./infrastructure/scripts/DeployMain.bat
   ```
   *This script handles resource group creation, Bicep template deployment, and Entra ID configuration.*

### 2. Application Deployment

To build and deploy the Flutter web application to Azure Static Web Apps:

1. Ensure you are logged into Azure via `az login`.
2. Run the application deployment script:
   ```powershell
   powershell -File ./infrastructure/scripts/DeployApp.ps1
   ```
   *This will build the Flutter web app with the necessary production environment variables and deploy it to the configured SWA resource.*

---

## 🏗️ Architecture & Documentation

### MOCC Schema
The following diagram illustrates the data schema and relationships within the MOCC ecosystem.

![MOCC Schema](./documentation/MOCC%20Schema.png)

### MOCC Function Apps
Overview of the serverless function components handling asynchronous tasks and integrations.

![MOCC Function Apps](./documentation/MOCC%20Function%20Apps.png)

---

Developed with ❤️ for MOCC.