param location string = 'italynorth'
param apimName string = 'moccapim'
param publisherEmail string = 'cosenzamario@proton.me'
param publisherName string = 'MOCC'
param backendBaseUrl string
param expectedAudience string
param backendClientId string
param requiredScope string

param functionAppUrl string
#disable-next-line secure-secrets-in-params
param functionKey string = 'manual-update-required'

param apiName string = 'mocc-api'
param apiPath string = 'query'
param tags object = {}
param backendName string = 'moccbackend'

@description('APIM Named Value used by policies to resolve the backend URL')
param backendBaseUrlNamedValue string = 'backend-base-url'

var schemaContent = loadTextContent('../../../backend/graph/schema.graphqls')
var policyContent = loadTextContent('policy.xml')
var policyContentAud = replace(policyContent, '__EXPECTED_AUDIENCE__', expectedAudience)
var policyContentAud2 = replace(policyContentAud, '__EXPECTED_AUDIENCE_CLIENT_ID__', backendClientId)
var policyContentFinal = replace(policyContentAud2, '__REQUIRED_SCOPE__', requiredScope)

resource apim 'Microsoft.ApiManagement/service@2025-03-01-preview' = {
  name: apimName
  location: location
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  tags: tags
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

resource backend 'Microsoft.ApiManagement/service/backends@2025-03-01-preview' = {
  parent: apim
  name: backendName
  properties: {
    url: backendBaseUrl
    protocol: 'http'
  }
}

resource backendUrlNv 'Microsoft.ApiManagement/service/namedValues@2025-03-01-preview' = {
  parent: apim
  name: backendBaseUrlNamedValue
  properties: {
    displayName: backendBaseUrlNamedValue
    value: backendBaseUrl
    secret: false
  }
}

resource functionUrlNv 'Microsoft.ApiManagement/service/namedValues@2025-03-01-preview' = {
  parent: apim
  name: 'function-app-url'
  properties: {
    displayName: 'function-app-url'
    value: functionAppUrl
    secret: false
  }
}

resource functionKeyNv 'Microsoft.ApiManagement/service/namedValues@2025-03-01-preview' = {
  parent: apim
  name: 'function-key'
  properties: {
    displayName: 'function-key'
    value: functionKey
    secret: true
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2025-03-01-preview' = {
  parent: apim
  name: apiName
  properties: {
    displayName: 'MOCC GraphQL API'
    path: apiPath
    type: 'graphql'
    serviceUrl: '${backendBaseUrl}/query'
    subscriptionRequired: false
    protocols: [ 'https', 'wss' ]
  }
}

resource apiSchema 'Microsoft.ApiManagement/service/apis/schemas@2025-03-01-preview' = {
  parent: api
  name: 'graphql'
  properties: {
    contentType: 'application/vnd.ms-azure-apim.graphql.schema'
    document: {
      value: schemaContent
    }
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2025-03-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    value: policyContentFinal
    format: 'xml'
  }
}

output apimName string = apim.name
output resourceGroupName string = resourceGroup().name
