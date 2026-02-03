@description('Azure Region')
param location string = 'swedencentral'

@description('Name of the unified AI Hub resource')
param hubName string = 'mocc-aihub'

@description('Name of the unified Project')
param projectName string = 'mocc-ai-project'

@description('OpenAI deployment name')
param openAiDeploymentName string = 'gpt-4o-mini'

@description('OpenAI model version')
param openAiModelVersion string = '2024-07-18'

@description('Deployment capacity')
param openAiCapacity int = 50

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
    description: 'MOCC AI Project'
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


output aiHubEndpoint string = aiHub.properties.endpoint
output aiHubId string = aiHub.id
output aiHubPrincipalId string = aiHub.identity.principalId

output aiProjectId string = aiProject.id
output aiProjectPrincipalId string = aiProject.identity.principalId

output openAiEndpoint string = aiHub.properties.endpoint
output openAiDeployment string = gptModel.name
output aiHubName string = aiHub.name
