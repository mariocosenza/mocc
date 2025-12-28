param location string = 'italynorth'

@description('Managed identity principalId (objectId) of the Function App.')
param functionPrincipalId string

@description('Managed identity principalId (objectId) of the App Service.')
param appServicePrincipalId string

var redisName = 'mocc-redis'
var databaseName = 'default'
var redisPort = 10000

resource redisEnterprise 'Microsoft.Cache/redisEnterprise@2025-07-01' = {
  name: redisName
  location: location
  sku: {
    name: 'Balanced_B0'
  }
  properties: {
    minimumTlsVersion: '1.2'
    highAvailability: 'Disabled'
    publicNetworkAccess: 'Enabled'
  }
}

resource redisDb 'Microsoft.Cache/redisEnterprise/databases@2025-07-01' = {
  parent: redisEnterprise
  name: databaseName
  properties: {
    clientProtocol: 'Encrypted'       
    port: redisPort                  
    clusteringPolicy: 'OSSCluster'
    evictionPolicy: 'VolatileLRU'
    accessKeysAuthentication: 'Disabled'
  }
}

resource fnRedisAccess 'Microsoft.Cache/redisEnterprise/databases/accessPolicyAssignments@2025-07-01' = {
  parent: redisDb
  name: 'moccfunctions'
  properties: {
    accessPolicyName: 'default'
    user: {
      objectId: functionPrincipalId
    }
  }
}

resource appRedisAccess 'Microsoft.Cache/redisEnterprise/databases/accessPolicyAssignments@2025-07-01' = {
  parent: redisDb
  name: 'moccappservice'
  properties: {
    accessPolicyName: 'default'
    user: {
      objectId: appServicePrincipalId
    }
  }
}

output redisEnterpriseId string = redisEnterprise.id
output redisDatabaseId string = redisDb.id
output redisHost string = '${redisEnterprise.name}.${location}.redis.azure.net'
output redisPort int = redisPort
output redisDatabaseName string = databaseName
