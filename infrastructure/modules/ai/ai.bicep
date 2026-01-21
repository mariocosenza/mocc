@description('Azure Region')
param location string = 'swedencentral'

@description('Name of the unified AI Hub resource')
param hubName string = 'mocc-ai-hub'

@description('Name of the unified Project')
param projectName string = 'mocc-ai-project'

@description('Function App managed identity principalId (objectId)')
param functionPrincipalId string

@description('OpenAI deployment name')
param openAiDeploymentName string = 'gpt-4o-mini'

@description('OpenAI model version')
param openAiModelVersion string = '2024-07-18'

@description('Deployment capacity')
param openAiCapacity int = 15

var cognitiveServicesUserRole = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'a97b65f3-24c7-4388-baec-2e87135dc908'
)

var openAiContributorRole = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
)

resource aiHub 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' = {
  name: hubName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned' 
  }
  properties: {
    customSubDomainName: toLower(hubName)
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
    allowProjectManagement: true
  }
}

resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2025-10-01-preview' = {
  parent: aiHub
  name: projectName
  location: location
  identity: {
    type: 'SystemAssigned' 
  }
  properties: {
    displayName: projectName
    description: 'Mocc AI Project'
  }
}

resource gptModel 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: aiHub
  name: openAiDeploymentName
  sku: {
    name: 'GlobalStandard'
    capacity: openAiCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: openAiModelVersion
    }
  }
}

resource hubRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiHub
  name: guid(aiHub.id, functionPrincipalId, cognitiveServicesUserRole)
  properties: {
    roleDefinitionId: cognitiveServicesUserRole
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource openAiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiHub
  name: guid(aiHub.id, functionPrincipalId, openAiContributorRole)
  properties: {
    roleDefinitionId: openAiContributorRole
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output aiHubEndpoint string = aiHub.properties.endpoint
output aiHubId string = aiHub.id
output aiHubPrincipalId string = aiHub.identity.principalId // System Assigned Principal ID

output aiProjectId string = aiProject.id
output aiProjectPrincipalId string = aiProject.identity.principalId

output openAiEndpoint string = aiHub.properties.endpoint
output openAiDeployment string = gptModel.name
