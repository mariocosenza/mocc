param location string = 'westeurope'
param functionPrincipalId string
var redisName = 'mocc-redis-${uniqueString(resourceGroup().id)}'

resource redis 'Microsoft.Cache/redis@2024-11-01' = {
  name: redisName
  location: location
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    redisConfiguration: {
      'aad-enabled': 'true'
    }
  }
}

resource fnRedisAccess 'Microsoft.Cache/redis/accessPolicyAssignments@2024-11-01' = {
  parent: redis
  name: 'mocc-functions'
  properties: {
    accessPolicyName: 'Data Contributor'
    objectId: functionPrincipalId
    objectIdAlias: 'mocc-functions-mi'
  }
}

output redisId string = redis.id
output redisHost string = '${redis.name}.redis.cache.windows.net'
