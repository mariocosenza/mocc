param location string = 'westeurope'

var storageName = toLower(take('moccfnsa${uniqueString(resourceGroup().id)}', 24))
var planName = 'mocc-fn-plan'
var functionAppName = 'mocc-functions-${uniqueString(resourceGroup().id)}'

resource sa 'Microsoft.Storage/storageAccounts@2022-09-01' = {
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

resource plan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: planName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource func 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }

  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'Python|3.11'
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${sa.name};AccountKey=${sa.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
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

output functionAppName string = func.name
output functionHost string = 'https://${func.properties.defaultHostName}'
output functionPrincipalId string = func.identity.principalId
output functionTenantId string = func.identity.tenantId
