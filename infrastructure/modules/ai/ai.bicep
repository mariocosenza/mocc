param location string = 'swedencentral'

@description('Foundry resource name for Document AI')
param docIntelName string = 'moccdocintel'

@description('Foundry resource name for Azure OpenAI')
param openAiName string = 'moccopenai'

@description('Foundry project name under the Document AI Foundry resource')
param docIntelProjectName string = '${docIntelName}-project'

@description('Foundry project name under the OpenAI Foundry resource')
param openAiProjectName string = '${openAiName}-project'

@description('SKU for the Document AI Foundry resource (commonly S0)')
param docIntelSku string = 'S0'

@description('SKU for the OpenAI resource (commonly S0)')
param openAiSku string = 'S0'

@description('Function App managed identity principalId (objectId) to grant access to AI resources')
param functionPrincipalId string

@description('OpenAI deployment name (used as model=... in code)')
param openAiDeploymentName string = 'gpt-4o-mini'

@description('OpenAI model version')
param openAiModelVersion string = '2024-07-18'

@description('Deployment capacity')
param openAiCapacity int = 10

var openAiUserRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
)

var cognitiveServicesUserRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'a97b65f3-24c7-4388-baec-2e87135dc908'
)

resource docintel 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' = {
  name: docIntelName
  location: location
  sku: {
    name: docIntelSku
  }
  kind: 'AIServices'
  properties: {
    publicNetworkAccess: 'Enabled'
    allowProjectManagement: true
    customSubDomainName: toLower(docIntelName)
    disableLocalAuth: true
  }
}

resource docintelProject 'Microsoft.CognitiveServices/accounts/projects@2025-10-01-preview' = {
  parent: docintel
  name: docIntelProjectName
  location: location
  properties: {
    displayName: docIntelProjectName
    description: 'MOCC Document AI project'
  }
}

resource openai 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' = {
  name: openAiName
  location: location
  sku: {
    name: openAiSku
  }
  kind: 'OpenAI'
  properties: {
    publicNetworkAccess: 'Enabled'
    customSubDomainName: toLower(openAiName)
    disableLocalAuth: true
  }
}

resource openaiProject 'Microsoft.CognitiveServices/accounts/projects@2025-10-01-preview' = {
  parent: openai
  name: openAiProjectName
  location: location
  properties: {
    displayName: openAiProjectName
    description: 'MOCC OpenAI project'
  }
}

resource openAiDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openai
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

resource openAiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: openai
  name: guid(openai.id, functionPrincipalId, openAiUserRoleDefinitionId)
  properties: {
    roleDefinitionId: openAiUserRoleDefinitionId
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource docIntelRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: docintel
  name: guid(docintel.id, functionPrincipalId, cognitiveServicesUserRoleDefinitionId)
  properties: {
    roleDefinitionId: cognitiveServicesUserRoleDefinitionId
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output docIntelEndpoint string = docintel.properties.endpoint
output docIntelProjectId string = docintelProject.id
output openAiEndpoint string = 'https://${openai.name}.openai.azure.com/'
output openAiProjectId string = openaiProject.id
output openAiDeployment string = openAiDeployment.name
