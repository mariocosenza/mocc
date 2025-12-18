var location = 'italynorth'

var storageName = toLower('moccfnsa${uniqueString(resourceGroup().id)}')
var planName = 'mocc-fn-plan'
var functionAppName = 'mocc-functions-${uniqueString(resourceGroup().id)}'

resource sa 'Microsoft.Storage/storageAccounts@2025-06-01' = {
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
  properties: {
    reserved: true
  }
}

resource func 'Microsoft.Web/sites@2025-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'Python|3.12'
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
          tag: 'AzureEventGrid'
        }
        {
          name: 'Allow-APIM'
          priority: 110
          action: 'Allow'
          tag: 'ApiManagement'
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
