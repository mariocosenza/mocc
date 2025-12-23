param location string = 'westeurope'
param apimName string = 'moccapimanager'
param publisherEmail string = 'admin@example.com'
param publisherName string = 'MOCC'
param backendBaseUrl string

param apiName string = 'mocc-api'
param apiPath string = 'graphql'
param tags object = {}

param tenantId string
param expectedAudience string
param requiredScope string = 'access_as_user'
param backendName string = 'moccbackend'

var policyXml = format('''
<policies>
  <inbound>
    <base />
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized">
      <openid-config url="https://login.microsoftonline.com/{0}/v2.0/.well-known/openid-configuration" />
      <audiences>
        <audience>{1}</audience>
      </audiences>
      <issuers>
        <issuer>https://login.microsoftonline.com/{0}/v2.0</issuer>
        <issuer>https://login.microsoftonline.com/9188040d-6c67-4c5b-b112-36a304b66dad/v2.0</issuer>
      </issuers>
      <required-claims>
        <claim name="scp" match="any" separator=" ">
          <value>{2}</value>
        </claim>
      </required-claims>
    </validate-jwt>

    <set-backend-service backend-id="{3}" />
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
''', tenantId, expectedAudience, requiredScope, backendName)

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
    protocol: 'http' // <--- THIS WAS MISSING
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: apiName
  properties: {
    displayName: apiName
    path: apiPath
    apiType: 'http'
    serviceUrl: backendBaseUrl
    subscriptionRequired: false
    protocols: [ // <--- Recommended to add this explicitly
      'https'
    ]
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: api
  name: 'policy'
  dependsOn: [
    backend
  ]
  properties: {
    format: 'rawxml'
    value: policyXml
  }
}

output apimGatewayUrl string = apim.properties.gatewayUrl
output apiBaseUrl string = '${apim.properties.gatewayUrl}/${apiPath}'
