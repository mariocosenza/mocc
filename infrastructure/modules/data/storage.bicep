param location string = resourceGroup().location
param storageAccountName string

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
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: false
    accessTier: 'Hot'
    publicNetworkAccess: 'Enabled'
    allowCrossTenantReplication: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny' 
    }
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

output storageAccountName string = storageAccount.name
