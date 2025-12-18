targetScope = 'resourceGroup'

var location = 'italynorth'
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
  }
}

output redisId string = redis.id
output redisHost string = '${redis.name}.redis.cache.windows.net'
