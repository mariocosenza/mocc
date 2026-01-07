param location string = 'italynorth'
param apimName string = 'moccapim'
param publisherEmail string = 'cosenzamario@proton.me'
param publisherName string = 'MOCC'
param backendBaseUrl string

param apiName string = 'mocc-api'
param apiPath string = 'graphql'
param tags object = {}
param backendName string = 'moccbackend'

@description('APIM Named Value used by policies to resolve the backend URL')
param backendBaseUrlNamedValue string = 'backend-base-url'

var schemaContent = loadTextContent('../../../backend/graph/schema.graphqls')

resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
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

resource backend 'Microsoft.ApiManagement/service/backends@2024-05-01' = {
  parent: apim
  name: backendName
  properties: {
    url: backendBaseUrl
    protocol: 'http'
  }
}

resource backendUrlNv 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: backendBaseUrlNamedValue
  properties: {
    displayName: backendBaseUrlNamedValue
    value: backendBaseUrl
    secret: false
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: apiName
  properties: {
    displayName: 'MOCC GraphQL API'
    path: apiPath
    type: 'graphql'
    serviceUrl: backendBaseUrl
    subscriptionRequired: false
    protocols: [ 'https', 'wss' ]
  }
}

resource apiSchema 'Microsoft.ApiManagement/service/apis/schemas@2024-05-01' = {
  parent: api
  name: 'graphql'
  properties: {
    contentType: 'application/vnd.ms-azure-apim.graphql.schema'
    document: {
      value: schemaContent
    }
  }
}

output apimName string = apim.name
output resourceGroupName string = resourceGroup().name
