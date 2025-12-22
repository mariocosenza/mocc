param location string = 'italynorth'
param environment string = 'dev'
param tags object = {}
param email string
param enableAppService bool = true
param enableFunctions bool = true
param enableRedis bool = true
param enableKeyVault bool = true
param enableStorage bool = true
param enableCosmos bool = false
param enableApim bool = true
param enableEventGrid bool = true
param enableNotificationHub bool = false
param enableAI bool = false
param storageAccountName string = 'moccstorageaccount'
param eventGridSystemTopicName string = 'moccblobeventgrid'

module storageMod './modules/data/storage.bicep' = if (enableStorage) {
  name: 'storage-${environment}'
  params: {
    location: location
    storageAccountName: storageAccountName
  }
}

module redisMod './modules/data/redis.bicep' = if (enableRedis) {
  name: 'redis-${environment}'
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
    tenantId: subscription().tenantId
    backendBaseUrl: enableAppService ? appServiceMod.outputs.appUrl : 'http://none'
  
    expectedAudience: identityMod.outputs.apiAudience 
  }
}

module eventGridMod './modules/integration/eventgrid.bicep' = if (enableEventGrid) {
  name: 'eventgrid-${environment}'
  params: {
    location: location
    systemTopicName: eventGridSystemTopicName
    storageAccountName: storageAccountName
  }
}

module notifHubMod './modules/integration/notifhub.bicep' = if (enableNotificationHub) {
  name: 'notifhub-${environment}'
  params: {
    namespaceName: 'moccnotification'
    location: location
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

output outLocation string = location
output outEnvironment string = environment
