param location string = 'italynorth'
param environment string = 'dev'
param tags object = {}
param email string
param enableAca bool = true
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

@description('App name (stable). Used for ACA name and other resource naming.')
param webAppName string = 'mocc-aca'

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
    location: 'westeurope'
    firebaseClientEmail: firebaseClientEmail
    firebasePrivateKey: firebasePrivateKey
    firebaseProjectId: firebaseProjectId
  }
}

module functionsMod './modules/compute/functions.bicep' = if (enableFunctions) {
  name: 'functions-${environment}'
  params: {cosmosDbEndpoint: 'https://mocccosmosdb.documents.azure.com:443/'}
}

module aiMod './modules/ai/ai.bicep' = if (enableAI) {
  name: 'ai-${environment}'
  params: {
    functionPrincipalId: functionsMod!.outputs.functionPrincipalId
  }
}

module aca './modules/compute/aca.bicep' = if (enableAca) {
  name: 'aca-${environment}'
  params: {
    location: location
    webAppName: webAppName
  }
}

module cosmos './modules/data/cosmos.bicep' = if (enableCosmos && enableAca) {
  name: 'cosmos-${environment}'
  params: {
    location: location
    databaseName: cosmosDatabaseName
    principalId: aca!.outputs.appPrincipalId
    functionPrincipalId: functionsMod!.outputs.functionPrincipalId
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
    appServicePrincipalId: enableAca ? aca!.outputs.appPrincipalId : ''
    functionPrincipalId: enableFunctions ? functionsMod!.outputs.functionPrincipalId : ''
  }
}

module apimMod './modules/integration/apim.bicep' = if (enableApim) {
  name: 'apim-${environment}'
  params: {
    location: location
    publisherEmail: email
    publisherName: 'MOCC'
    tags: tags
    backendBaseUrl: enableAca ? aca!.outputs.appUrl : 'https://example.com'
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
    appServicePrincipalId: aca!.outputs.appPrincipalId
  }
}

module kvSecurityMod './modules/security/keyvault.bicep' = if (enableKeyVault) {
  name: 'keyvault-security-${environment}'
  params: {
    location: location
    functionPrincipalId: functionsMod!.outputs.functionPrincipalId
    notifHubName: notifHubMod!.outputs.notificationHubName
    notifHubNamespace: notifHubMod!.outputs.notificationHubNamespaceName
    notifHubSasPolicyName: notifHubMod!.outputs.notifHubSasPolicyName
  }
}

output outLocation string = location
output outEnvironment string = environment

output resourceGroupName string = resourceGroup().name
output containerAppName string = enableAca ? aca!.outputs.appName : ''
output appUrl string = enableAca ? aca!.outputs.appUrl : ''
output appPrincipalId string = enableAca ? aca!.outputs.appPrincipalId : ''


output cosmosAccount string = (enableAca && enableCosmos) ? cosmosAccountName : ''
output cosmosDatabase string = cosmosDatabaseName
output cosmosEndpoint string = (enableAca && enableCosmos) ? cosmos!.outputs.cosmosEndpoint : ''
