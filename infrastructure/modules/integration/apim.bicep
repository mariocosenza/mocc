param location string = resourceGroup().location
param adminEmail string
param organizationName string
param tagsByResource object
param customProperties object
param identity object


resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: 'moccapimanager'
  location: location
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  identity: identity
  tags: tagsByResource
  properties: {
    publisherEmail: adminEmail
    publisherName: organizationName
    customProperties: customProperties
  }
}
