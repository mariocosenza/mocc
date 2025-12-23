param accountName string = 'sql-${uniqueString(resourceGroup().id)}'
param location string = resourceGroup().location
param databaseName string = 'mocc-db'


resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2025-10-15' = {
  name: toLower(accountName)
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: 'westeurope'
        failoverPriority: 0
        isZoneRedundant: false
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

resource inventoryContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2025-10-15' = {
  parent: cosmosDatabase
  name: 'Inventory'
  properties: {
    resource: {
      id: 'Inventory'
      partitionKey: {
        paths: ['/fridgeId']
        kind:'Hash'
      }
    }
  }
}

resource cookbookContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2025-10-15' = {
  parent: cosmosDatabase
  name: 'Cookbook'
  properties: {
    resource: {
      id: 'Cookbook'
      partitionKey: {
        paths: ['/authorId']
        kind:'Hash'
      }
      defaultTtl: -1
    }
  }
}

resource socialContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2025-10-15' = {
  parent: cosmosDatabase
  name: 'Social'
  properties: {
    resource: {
      id: 'Social'
      partitionKey: {
        paths: ['/type'] 
        kind:'Hash'
      }
    }
  }
}

resource usersContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2025-10-15' = {
  parent: cosmosDatabase
  name: 'Users'
  properties: {
    resource: {
      id: 'Users'
      partitionKey: {
        paths: ['/id']
        kind: 'Hash'
      }
    }
  }
}

resource historyContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2025-10-15' = {
  parent: cosmosDatabase
  name: 'History'
  properties: {
    resource: {
      id: 'History'
      partitionKey: { paths: ['/userId'], kind: 'Hash' }
    }
  }
}

resource stagingContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2025-10-15' = {
  parent: cosmosDatabase
  name: 'Staging'
  properties: {
    resource: {
      id: 'Staging'
      partitionKey: { paths: ['/id'], kind: 'Hash' }
      defaultTtl: -1 
    }
  }
}

resource leaderboardContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2025-10-15' = {
  parent: cosmosDatabase
  name: 'Leaderboard'
  properties: {
    resource: {
      id: 'Leaderboard'
      partitionKey: { paths: ['/period'], kind: 'Hash' }
    }
  }
}

output location string = location

