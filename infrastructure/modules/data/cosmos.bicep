param accountName string = 'sql-${uniqueString(resourceGroup().id)}'
param location string = resourceGroup().location
param databaseName string = 'MOCC-DB'


resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2025-10-15' = {
  name: toLower(accountName)
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: 'italynorth'
        failoverPriority: 0
        isZoneRedundant: true
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Local'
      }
    }
    isVirtualNetworkFilterEnabled: false
    minimalTlsVersion: 'Tls12'
    enableMultipleWriteLocations: false
    enableFreeTier: true
    capacity: {
      totalThroughputLimit: 1000
    }
    disableLocalAuth: false

  }
}

resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2025-10-15' = {
  parent:cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }

}


output location string = location

