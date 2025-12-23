targetScope = 'resourceGroup'

var location = 'westeurope'
var keyVaultName = 'mocc-kv-${uniqueString(resourceGroup().id)}'

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

output keyVaultName string = kv.name
output keyVaultId string = kv.id
output vaultUri string = kv.properties.vaultUri
