param location string = 'westeurope'
param cosmosDbEndpoint string
param keyVaultUrl string
param openAiEndpoint string
param openAiDeployment string = 'gpt-4o-mini'
param mainStorageAccountName string = ''

var storageName = toLower(take('moccfnsa${uniqueString(resourceGroup().id)}', 24))
var planName = 'mocc-fn-plan'
var functionAppName = 'mocc-functions-${uniqueString(resourceGroup().id)}'
var linuxFxVersion = 'Python|3.12'


resource functionStorageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: storageName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource plan 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: planName
  location: location
  kind: 'functionapp'
  sku: { name: 'Y1', tier: 'Dynamic' }
  properties: {
    reserved: true
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: '${functionAppName}-logs'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: json('0.10')
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${functionAppName}-ai'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    SamplingPercentage: 100
  }
}

resource func 'Microsoft.Web/sites@2025-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorageAccount.name};AccountKey=${functionStorageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorageAccount.name};AccountKey=${functionStorageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'python' }
        { name: 'WEBSITE_RUN_FROM_PACKAGE', value: '1' }
        { name: 'COSMOS_URL', value: cosmosDbEndpoint }
        { name: 'AZURE_OPENAI_ENDPOINT', value: openAiEndpoint }
        { name: 'AZURE_OPENAI_DEPLOYMENT', value: openAiDeployment }
        { name: 'DOCUMENT_INTELLIGENCE_ENDPOINT', value: openAiEndpoint }
        { name: 'KEY_VAULT_URL', value: keyVaultUrl }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsights.properties.ConnectionString }
        { name: 'STORAGE_ACCOUNT_NAME', value: mainStorageAccountName }
      ]

      ipSecurityRestrictions: [
        { name: 'Allow-EventGrid', priority: 100, action: 'Allow', ipAddress: 'AzureEventGrid', tag: 'ServiceTag' }
        { name: 'Allow-AzureCloud', priority: 102, action: 'Allow', ipAddress: 'AzureCloud', tag: 'ServiceTag' }
        { name: 'Allow-APIM-ItalyNorth', priority: 105, action: 'Allow', ipAddress: 'ApiManagement.ItalyNorth', tag: 'ServiceTag' }
        { name: 'Allow-APIM', priority: 110, action: 'Allow', ipAddress: 'ApiManagement', tag: 'ServiceTag' }
        { name: 'Deny-All', priority: 200, action: 'Deny', ipAddress: '0.0.0.0/0' }
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

#disable-next-line outputs-should-not-contain-secrets
output defaultFunctionKey string = listKeys('${func.id}/host/default', '2022-03-01').functionKeys.default

