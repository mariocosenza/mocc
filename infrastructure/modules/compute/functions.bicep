param location string = 'westeurope'
param cosmosDbEndpoint string

var storageName = toLower(take('moccfnsa${uniqueString(resourceGroup().id)}', 24))
var planName = 'mocc-fn-plan'
var functionAppName = 'mocc-functions-${uniqueString(resourceGroup().id)}'

resource functionStorageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource plan 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: planName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

resource func 'Microsoft.Web/sites@2025-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorageAccount.name};AccountKey=${functionStorageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'COSMOS_ENDPOINT'
          value: cosmosDbEndpoint
        }
        {
          name: 'AZURE_OPENAI_ENDPOINT'
          value: 'https://moccopenai.openai.azure.com/'
        }
        {
          name: 'AZURE_OPENAI_DEPLOYMENT'
          value: 'gpt-4o-mini'
        }
        
      ]
      ipSecurityRestrictions: [
        {
          name: 'Allow-EventGrid'
          priority: 100
          action: 'Allow'
          ipAddress: 'AzureEventGrid'
          tag: 'ServiceTag'
        }
        {
          name: 'Allow-APIM'
          priority: 110
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

output functionAppId string = func.id
output functionAppName string = func.name
output functionHost string = 'https://${func.properties.defaultHostName}'
output functionPrincipalId string = func.identity.principalId
output functionTenantId string = func.identity.tenantId
output functionStorageAccountName string = functionStorageAccount.name
