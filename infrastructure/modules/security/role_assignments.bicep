param storageAccountName string
param functionPrincipalId string
param principalType string = 'ServicePrincipal'

@description('Role Definition ID for Storage Blob Data Contributor')
var roleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
@description('Role Definition ID for SignalR Service Contributor')
var signalIRRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'fd53cd77-2268-407a-8f46-7e7863d0f521')

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' existing = {
  name: storageAccountName
}

resource signalIR 'Microsoft.SignalRService/SignalR@2024-10-01-preview' existing = {
  name: 'moccsignalr'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, functionPrincipalId, roleDefinitionId)
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: functionPrincipalId
    principalType: principalType
  }
}

resource signalIRRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: signalIR
  name: guid(signalIR.id, functionPrincipalId, signalIRRoleDefinitionId)
  properties: {
    roleDefinitionId: signalIRRoleDefinitionId
    principalId: functionPrincipalId
    principalType: principalType
  }
}

