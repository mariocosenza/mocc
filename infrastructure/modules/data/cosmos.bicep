@description('Azure Region')
param location string = 'italynorth'

@description('Cosmos DB account name (fixed)')
param fixedAccountName string = 'mocccosmosdb'

@description('SQL database name')
param databaseName string

@description('App Service managed identity principalId (objectId)')
param principalId string

@description('Function App managed identity principalId (objectId)')
param functionPrincipalId string

var cosmosDataContributorRoleDefGuid = '00000000-0000-0000-0000-000000000002'
var contributorRoleGuid = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var contributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleGuid)
var roleDefinitionId = '${cosmosAccount.id}/sqlRoleDefinitions/${cosmosDataContributorRoleDefGuid}'

var cosmosThroughputLimitPolicyGuid = '0b7ef78e-a035-4f23-b9bd-aff122a1b1cf'
var cosmosThroughputLimitPolicyDefId = tenantResourceId('Microsoft.Authorization/policyDefinitions', cosmosThroughputLimitPolicyGuid)

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2025-10-15' = {
  name: fixedAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    disableLocalAuth: true
    locations: [
      {
        locationName: location
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
    options: {
      throughput: 400
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

resource cosmosMgmtContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: cosmosAccount
  name: guid(cosmosAccount.id, functionPrincipalId, contributorRoleGuid)
  properties: {
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRoleId
  }
}

resource cosmosSqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2025-10-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, principalId, cosmosDataContributorRoleDefGuid)
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    scope: cosmosAccount.id
  }
}

resource functionCosmosSqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2025-10-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, functionPrincipalId, cosmosDataContributorRoleDefGuid)
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: functionPrincipalId
    scope: cosmosAccount.id
  }
}

resource cosmosThroughputCapPolicyAssignment 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: 'cosmos-throughput-cap-400'
  location: location
  properties: {
    displayName: 'Cosmos DB throughput cap 400 RU/s'
    policyDefinitionId: cosmosThroughputLimitPolicyDefId
    parameters: {
      effect: {
        value: 'Deny'
      }
      throughputMax: {
        value: 400
      }
    }
  }
}

output cosmosAccountName string = cosmosAccount.name
output cosmosEndpoint string = cosmosAccount.properties.documentEndpoint
output sqlDatabaseName string = cosmosDatabase.name
output policyAssignmentName string = cosmosThroughputCapPolicyAssignment.name
