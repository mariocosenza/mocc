param location string = 'westeurope'
param apimName string = 'moccapim'
param publisherEmail string = 'admin@example.com'
param publisherName string = 'MOCC'
param backendBaseUrl string

param apiName string = 'mocc-api'
param apiPath string = 'graphql'
param tags object = {}
param backendName string = 'moccbackend'

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
