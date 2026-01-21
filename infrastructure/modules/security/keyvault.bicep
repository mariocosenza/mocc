targetScope = 'resourceGroup'

param location string = 'westeurope'

@description('Function App system-assigned managed identity principalId (from the function deployment output).')
param functionPrincipalId string


param notifHubNamespace string
param notifHubName string
param notifHubSasPolicyName string

var keyVaultName = 'mocckv'
var kvSecretsUserRoleGuid = '4633458b-17de-408a-b874-0445c86b69e6' 

resource nhNamespace 'Microsoft.NotificationHubs/namespaces@2023-10-01-preview' existing = {
  name: 'moccnotifdev'
}

resource nh 'Microsoft.NotificationHubs/namespaces/notificationHubs@2023-10-01-preview' existing = {
  parent: nhNamespace
  name: 'moccnotificationhub'
}

resource nhSendRule 'Microsoft.NotificationHubs/namespaces/notificationHubs/authorizationRules@2023-10-01-preview' existing = {
  parent: nh
  name: notifHubSasPolicyName
}

var sendRuleKeys = nhSendRule.listKeys()

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

resource kvSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: kv
  name: guid(kv.id, functionPrincipalId, kvSecretsUserRoleGuid)
  properties: {
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsUserRoleGuid)
  }
}


resource nhNamespaceSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'notifHub-namespace'
  dependsOn: [ kvSecretsUserAssignment ]
  properties: { value: notifHubNamespace }
}

resource nhNameSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'notifHub-name'
  dependsOn: [ kvSecretsUserAssignment ]
  properties: { value: notifHubName }
}

resource nhPolicySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'notifHub-sas-policy-name'
  dependsOn: [ kvSecretsUserAssignment ]
  properties: { value: notifHubSasPolicyName }
}

resource nhSasPrimary 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'notifHub-sas-primary'
  dependsOn: [ kvSecretsUserAssignment ]
  properties: { value: sendRuleKeys.primaryKey }
}

resource nhSasSecondary 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'notifHub-sas-secondary'
  dependsOn: [ kvSecretsUserAssignment ]
  properties: { value: sendRuleKeys.secondaryKey }
}

resource nhConnStr 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'notifHub-connection-string'
  dependsOn: [ kvSecretsUserAssignment ]
  properties: { value: sendRuleKeys.primaryConnectionString }
}

output keyVaultName string = kv.name
output vaultUri string = kv.properties.vaultUri
