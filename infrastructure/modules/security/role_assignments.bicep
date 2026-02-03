param storageAccountName string
param functionPrincipalId string
param principalType string = 'ServicePrincipal'
param aiHubName string = ''

var storageBlobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
var signalRServiceOwnerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7e4f1700-ea5a-4f59-8f37-079cfe29dce3')
var cognitiveServicesOpenAiUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' existing = {
  name: storageAccountName
}

resource signalR 'Microsoft.SignalRService/SignalR@2024-10-01-preview' existing = {
  name: 'moccsignalr'
}

resource aiHub 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' existing = if (!empty(aiHubName)) {
  name: aiHubName
}

resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, functionPrincipalId, storageBlobDataContributorRoleId)
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleId
    principalId: functionPrincipalId
    principalType: principalType
  }
}

resource signalRServiceOwnerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: signalR
  name: guid(signalR.id, functionPrincipalId, signalRServiceOwnerRoleId)
  properties: {
    roleDefinitionId: signalRServiceOwnerRoleId
    principalId: functionPrincipalId
    principalType: principalType
  }
}
resource aiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(aiHubName)) {
  scope: aiHub
  name: guid(aiHub.id, functionPrincipalId, cognitiveServicesOpenAiUserRoleId)
  properties: {
    roleDefinitionId: cognitiveServicesOpenAiUserRoleId
    principalId: functionPrincipalId
    principalType: principalType
  }
}
