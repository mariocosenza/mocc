param location string = resourceGroup().location

param environment string = 'dev'

var acrName = toLower(take('moccacr${uniqueString(resourceGroup().id)}', 50))
var webAppName = 'mocc-app-${environment}-${uniqueString(resourceGroup().id)}'
var planName = '${webAppName}-plan'

var imageRepoAndTag = 'mocc-backend:latest'
var containerPort = 80

var acrLoginServer = '${acrName}.azurecr.io'
var mainImage = '${acrLoginServer}/${imageRepoAndTag}'

var acrPullRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)

resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

resource plan 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: planName
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource app 'Microsoft.Web/sites@2025-03-01' = {
  name: webAppName
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|${mainImage}'
      alwaysOn: true
      appSettings: [
        {
          name: 'WEBSITES_PORT'
          value: string(containerPort)
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_ENABLE_CI'
          value: 'true'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acrLoginServer}'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_AUTHENTICATION_TYPE'
          value: 'ManagedIdentity'
        }
      ]
      ipSecurityRestrictions: [
        {
          name: 'Allow-APIM'
          priority: 100
          action: 'Allow'
          ipAddress: 'ApiManagement' 
          tag: 'ServiceTag'
        }
        {
          name: 'Deny-All'
          priority: 200
          action: 'Deny'
          ipAddress: '0.0.0.0/0'
        }
      ]
    }
  }
}

resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, webAppName, acrPullRoleDefinitionId)
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: app.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output acrLogin string = acr.properties.loginServer
output appUrl string = 'https://${app.properties.defaultHostName}'
