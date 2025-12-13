@description('Key Vault name (globally unique)')
param keyVaultName string

@description('Location (defaults to RG location)')
param location string = resourceGroup().location

@description('Optional: Principal (object) ID of your Azure Function system-assigned managed identity. If empty, no role assignment is created.')
param functionPrincipalId string = ''


var keyVaultSecretsUserRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)

resource kv 'Microsoft.KeyVault/vaults@2025-05-01' = {
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

resource kvSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (functionPrincipalId != '') {
  scope: kv
  name: guid(kv.id, functionPrincipalId, keyVaultSecretsUserRoleId)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleId
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output vaultUri string = kv.properties.vaultUri
