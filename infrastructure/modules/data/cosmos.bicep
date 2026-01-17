param location string = 'italynorth'
param fixedAccountName string = 'mocccosmosdb'

param databaseName string

@description('App Service managed identity principalId (objectId)')
param principalId string
param functionPrincipalId string

var cosmosDataContributorRoleDefGuid = '00000000-0000-0000-0000-000000000002'

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2025-10-15' = {
  name: fixedAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    disableLocalAuth: true

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

    enableFreeTier: true
  }
}

resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2025-10-15' = {
  parent: cosmosAccount
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
      partitionKey: { paths: [ '/fridgeId' ], kind: 'Hash' }
    }
  }
}

resource cookbookContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2025-10-15' = {
  parent: cosmosDatabase
  name: 'Cookbook'
  properties: {
    resource: {
      id: 'Cookbook'
      partitionKey: { paths: [ '/authorId' ], kind: 'Hash' }
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
      partitionKey: { paths: [ '/type' ], kind: 'Hash' }
    }
  }
}

resource usersContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2025-10-15' = {
  parent: cosmosDatabase
  name: 'Users'
  properties: {
    resource: {
      id: 'Users'
      partitionKey: { paths: [ '/id' ], kind: 'Hash' }
    }
  }
}

resource historyContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2025-10-15' = {
  parent: cosmosDatabase
  name: 'History'
  properties: {
    resource: {
      id: 'History'
      partitionKey: { paths: [ '/userId' ], kind: 'Hash' }
    }
  }
}

resource stagingContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2025-10-15' = {
  parent: cosmosDatabase
  name: 'Staging'
  properties: {
    resource: {
      id: 'Staging'
      partitionKey: { paths: [ '/id' ], kind: 'Hash' }
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
      partitionKey: { paths: [ '/period' ], kind: 'Hash' }
    }
  }
}

var roleDefinitionId = '${cosmosAccount.id}/sqlRoleDefinitions/${cosmosDataContributorRoleDefGuid}'

resource cosmosSqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2025-10-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, principalId, functionPrincipalId, cosmosDataContributorRoleDefGuid)
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    scope: cosmosAccount.id
  }
}

output cosmosAccountName string = cosmosAccount.name
output cosmosEndpoint string = cosmosAccount.properties.documentEndpoint
output databaseName string = databaseName
