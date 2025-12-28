param location string = 'westeurope'
param environment string = 'dev'
param tags object = {}
param email string
param enableAppService bool = true
param enableFunctions bool = true
param enableRedis bool = true
param enableKeyVault bool = true
param enableStorage bool = true
param enableCosmos bool = true
param enableApim bool = true
param enableEventGrid bool = true
param enableNotificationHub bool = true
param enableAI bool = true

param storageAccountName string = 'moccstorage${uniqueString(resourceGroup().id)}'
param eventGridSystemTopicName string = 'moccblobeventgrid'

param cosmosAccountName string = toLower('sql-${uniqueString(resourceGroup().id)}')
param cosmosDatabaseName string = 'mocc-db'

@description('App Service name (must be stable because it is used in sites/config name).')
param webAppName string = 'mocc-app-service'

@secure()
@description('Firebase service account JSON (downloaded from Firebase/Google Cloud).')
param firebaseServiceAccount object

@description('Blob container that receives client uploads (used for Event Grid filtering).')
param uploadsContainerName string = 'uploads'

var firebaseProjectId = firebaseServiceAccount.project_id
var firebaseClientEmail = firebaseServiceAccount.client_email
var firebasePrivateKey = firebaseServiceAccount.private_key

module notifHubMod './modules/integration/notifhub.bicep' = if (enableNotificationHub) {
  name: 'notifhub-${environment}'
  params: {
    location: location
    firebaseClientEmail: firebaseClientEmail
    firebasePrivateKey: firebasePrivateKey
    firebaseProjectId: firebaseProjectId
  }
}

module aiMod './modules/ai/ai.bicep' = if (enableAI) {
  name: 'ai-${environment}'
  params: {
    location: location
    docIntelName: 'moccdocintel'
    openAiName: 'moccopenai'
  }
}

module kvSecurityMod './modules/security/keyvault.bicep' = if (enableKeyVault) {
  name: 'keyvault-security-${environment}'
  params: {
    location: location
    keyVaultName: 'mocckv'
  }
}

module kvDataMod './modules/data/keyvault.bicep' = if (enableKeyVault) {
  name: 'keyvault-data-${environment}'
  params: {}
}

module app './modules/compute/appservice.bicep' = if (enableAppService) {
  name: 'appservice-${environment}'
  params: {
    location: location
    webAppName: webAppName
  }
}



module functionsMod './modules/compute/functions.bicep' = if (enableFunctions) {
  name: 'functions-${environment}'
  params: {}
}

module cosmos './modules/data/cosmos.bicep' = if (enableCosmos && enableAppService) {
  name: 'cosmos-${environment}'
  params: {
    location: location
    accountName: cosmosAccountName
    databaseName: cosmosDatabaseName
    principalId: app!.outputs.appPrincipalId
    functionPrincipalId: functionsMod!.outputs.functionAppId
  }
}

module identityMod './modules/integration/api-appreg.bicep' = {
  name: 'identity-${environment}'
  params: {
    apiAppDisplayName: 'mocc-api-${environment}'
  }
}

module storageMod './modules/data/storage.bicep' = if (enableStorage) {
  name: 'storage-${environment}'
  params: {
    storageAccountName: storageAccountName
    location: location
    uploadsContainerName: uploadsContainerName
    publicNetworkAccessEnabled: true
    corsAllowedOrigins: ['mocc.azurestaticapps.net']
    appServicePrincipalId: app!.outputs.appPrincipalId
    functionPrincipalId: functionsMod!.outputs.functionPrincipalId
  }
}

module apimMod './modules/integration/apim.bicep' = if (enableApim) {
  name: 'apim-${environment}'
  params: {
    location: location
    publisherEmail: email
    publisherName: 'MOCC'
    tags: tags
    backendBaseUrl: enableAppService ? 'https://${app!.outputs.appUrl}' : 'https://example.com'
  }
}

module eventGridMod './modules/integration/eventgrid.bicep' = if (enableEventGrid && enableStorage && enableFunctions) {
  name: 'eventgrid-${environment}'
  params: {
    location: location
    systemTopicName: eventGridSystemTopicName
    storageAccountName: storageMod!.outputs.storageAccountName
  }
}

module redisMod './modules/data/redis.bicep' = if (enableRedis && enableFunctions) {
  name: 'redis-${environment}'
  params: {
    functionPrincipalId: functionsMod!.outputs.functionPrincipalId
    appServicePrincipalId: app!.outputs.appPrincipalId
  }
}

resource appSettings 'Microsoft.Web/sites/config@2025-03-01' = if (enableAppService && enableCosmos) {
  name: '${webAppName}/appsettings'
  properties: {
    COSMOS_ENDPOINT: cosmos!.outputs.cosmosEndpoint
    COSMOS_DATABASE: cosmosDatabaseName
  }
}

output outLocation string = location
output outEnvironment string = environment

output appUrl string = enableAppService ? app!.outputs.appUrl : ''
output cosmosEndpoint string = (enableAppService && enableCosmos) ? cosmos!.outputs.cosmosEndpoint : ''
