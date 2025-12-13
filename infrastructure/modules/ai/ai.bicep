targetScope = 'resourceGroup'

param location string = resourceGroup().location

@description('Document Intelligence resource name (globally unique)')
param docIntelName string

@description('Azure OpenAI resource name (globally unique)')
param openAiName string

@allowed([
  'F0'
  'S0'
])
@description('Document Intelligence SKU: use F0 if available, otherwise S0')
param docIntelSku string = 'F0'

@description('Azure OpenAI SKU (commonly S0)')
param openAiSku string = 'S0'


resource docintel 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' = {
  name: docIntelName
  location: location
  sku: {
    name: docIntelSku
  }
  kind: 'FormRecognizer'
  properties: {
    publicNetworkAccess: 'Enabled'
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
  }
}

output docIntelEndpoint string = docintel.properties.endpoint
output openAiEndpoint string = openai.properties.endpoint
