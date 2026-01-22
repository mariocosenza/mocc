@description('Deployment location.')
param location string = resourceGroup().location

@description('Globally unique storage account name (lowercase letters/numbers only).')
param storageAccountName string

@description('Name of the blob container used for client uploads.')
param uploadsContainerName string = 'uploads'

@description('If you use Flutter Web, set allowed origins (e.g., https://app.example.com). For mobile-only, leave empty.')
param corsAllowedOrigins array = []

@description('If true, allow public network access. Required for direct-from-client uploads over the public internet.')
param publicNetworkAccessEnabled bool = true

@description('Optional principal id of a Function (service principal or managed identity). Leave empty to skip role assignment.')
param functionPrincipalId string

@description('Optional principal id of an App Service (service principal or managed identity). Leave empty to skip role assignment.')
param appServicePrincipalId string

var storageBlobDataReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')

var storageBlobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')


resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true

    accessTier: 'Hot'
    publicNetworkAccess: 'Enabled'

    networkAcls: publicNetworkAccessEnabled ? {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    } : {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }

    allowCrossTenantReplication: false
    dnsEndpointType: 'Standard'
    largeFileSharesState: 'Enabled'

    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: { enabled: true }
        file: { enabled: true }
        table: { enabled: true }
        queue: { enabled: true }
      }
      requireInfrastructureEncryption: false
    }
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2025-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: length(corsAllowedOrigins) > 0 ? [
        {
          allowedOrigins: corsAllowedOrigins
          allowedMethods: [
            'PUT'
            'GET'
            'HEAD'
            'OPTIONS'
          ]
          allowedHeaders: [
            '*'
          ]
          exposedHeaders: [
            '*'
          ]
          maxAgeInSeconds: 200
        }
      ] : []
    }

    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource uploadsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
  parent: blobServices
  name: uploadsContainerName
  properties: {
    publicAccess: 'None'
  }
}


resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2025-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource functionBlobReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(functionPrincipalId)) {
  scope: storageAccount
  name: guid(storageAccount.id, functionPrincipalId, storageBlobDataReaderRoleId)
  properties: {
    roleDefinitionId: storageBlobDataReaderRoleId
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource acaServiceBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(appServicePrincipalId)) {
  scope: storageAccount
  name: guid(storageAccount.id, appServicePrincipalId, storageBlobDataContributorRoleId)
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleId
    principalId: appServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output uploadsContainer string = uploadsContainerName
