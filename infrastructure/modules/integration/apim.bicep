targetScope = 'resourceGroup'

param location string = 'italynorth'

param apimName string = 'moccapimanager'
param publisherEmail string = 'admin@example.com'
param publisherName string = 'MOCC'

@description('Public base URL of your backend. Example: https://mocc.azurewebsites.net')
param backendBaseUrl string

@description('API name inside APIM')
param apiName string = 'mocc-api'

@description('Public API path. Example: graphql')
param apiPath string = 'graphql'

@description('Entra tenant ID (GUID)')
param tenantId string

@description('Expected audience (api://client-id)')
param expectedAudience string

@description('Required scope')
param requiredScope string = 'access_as_user'

param tags object = {}

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

resource api 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: apiName
  properties: {
    displayName: apiName
    path: apiPath
    protocols: [ 'https' ]
    apiType: 'http'
    subscriptionRequired: false
  }
}

resource backend 'Microsoft.ApiManagement/service/backends@2024-05-01' = {
  parent: apim
  name: 'mocc-backend'
  properties: {
    url: backendBaseUrl
    protocol: 'http'
  }
}

// [FIX] Updated Policy for Multi-Tenant / Personal Account Support
resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: api
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '''
<policies>
  <inbound>
    <base />
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized">
      <openid-config url="https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration" />
      
      <audiences>
        <audience>${expectedAudience}</audience>
      </audiences>
      
      <issuers>
        <issuer>https://login.microsoftonline.com/${tenantId}/v2.0</issuer>
        <issuer>https://login.microsoftonline.com/9188040d-6c67-4c5b-b112-36a304b66dad/v2.0</issuer>
      </issuers>

      <required-claims>
        <claim name="scp" match="any">
          <value>${requiredScope}</value>
        </claim>
      </required-claims>
    </validate-jwt>

    <set-backend-service backend-id="${backend.name}" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
'''
  }
}

output apimGatewayUrl string = apim.properties.gatewayUrl
output apiBaseUrl string = '${apim.properties.gatewayUrl}/${apiPath}'
