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
@secure()
@description('Firebase service account JSON (downloaded from Firebase/Google Cloud).')
param firebaseServiceAccount object

var firebaseProjectId = firebaseServiceAccount.project_id
var firebaseClientEmail = firebaseServiceAccount.client_email
var firebasePrivateKey = firebaseServiceAccount.private_key


module storageMod './modules/data/storage.bicep' = if (enableStorage) {
  name: 'storage-${environment}'
  params: {
    storageAccountName: storageAccountName
    location: location
  }
}

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
  params: {
  }
}

module cosmosMod './modules/data/cosmos.bicep' = if (enableCosmos) {
  name: 'cosmos-${environment}'
  params: {
    location: location
  }
}

module appServiceMod './modules/compute/appservice.bicep' = if (enableAppService) {
  name: 'appservice-${environment}'
  params: {
    location: location
  }
}

module functionsMod './modules/compute/functions.bicep' = if (enableFunctions) {
  name: 'functions-${environment}'
  params: {
  }
}

module identityMod './modules/integration/api-appreg.bicep' = {
  name: 'identity-${environment}'
  params: {
    apiAppDisplayName: 'mocc-api-${environment}' 
  }
}

module apimMod './modules/integration/apim.bicep' = if (enableApim) {
  name: 'apim-${environment}'
  params: {
    location: location
    publisherEmail: email
    publisherName: 'MOCC' 
    tags: tags
    backendBaseUrl: enableAppService ? 'https://${appServiceMod!.outputs.appUrl}' : 'https://example.com'
  }
}

module eventGridMod './modules/integration/eventgrid.bicep' = if (enableEventGrid) {
  name: 'eventgrid-${environment}'
  params: {
    location: location
    systemTopicName: eventGridSystemTopicName
    storageAccountName: enableStorage ? storageMod!.outputs.storageAccountName : ''
  }
}

module redisMod './modules/data/redis.bicep' = if (enableRedis) {
  name: 'redis-${environment}'
  params: {
    functionPrincipalId: functionsMod!.outputs.functionPrincipalId
  }
}


output outLocation string = location
output outEnvironment string = environment
