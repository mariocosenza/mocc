targetScope = 'subscription'
extension 'br:mcr.microsoft.com/bicep/extensions/microsoftgraph/v1.0:0.1.9-preview'

@description('Frontend (SPA + public client) app registration display name.')
param appName string = 'mocc-flutter-swa'

@description('Backend (API) app registration display name.')
param backendAppName string = 'mocc-backend-api'

@description('Static Web App URL')
param swaUrl string = 'https://mocc.azurestaticapps.net'
param localUrl string = 'http://localhost:4280'
param localUrl8000 string = 'http://localhost:8000'

@description('Android applicationId / package name, e.g. com.yourcompany.mocc')
param androidPackageName string = 'it.unisa.mocc'

@description('Base64 encoded signing certificate signature')
param androidSignatureHash string = 'GhA+HfJcocF4G9Oe5GK90xDBzHo='

@description('OAuth2 scope value exposed by the backend API (used in scp).')
param backendScopeValue string = 'access_as_user'

var androidRedirectUri = 'msauth://${androidPackageName}/${androidSignatureHash}'
var backendScopeId = guid(backendAppName, 'scope', backendScopeValue)

resource backendApp 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: backendAppName
  displayName: backendAppName
  signInAudience: 'AzureADandPersonalMicrosoftAccount'

  api: {
    requestedAccessTokenVersion: 2
    oauth2PermissionScopes: [
      {
        id: backendScopeId
        adminConsentDescription: 'Access MOCC API as the signed-in user'
        adminConsentDisplayName: 'Access MOCC API'
        userConsentDescription: 'Access MOCC API on your behalf'
        userConsentDisplayName: 'Access MOCC API'
        isEnabled: true
        type: 'User'
        value: 'access_as_user'
      }
    ]
  }
}


resource app 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: appName
  displayName: appName
  signInAudience: 'AzureADandPersonalMicrosoftAccount'

  spa: {
    redirectUris: [
      '${swaUrl}/'
      '${localUrl}/'
      '${localUrl8000}/'
    ]
  }

  publicClient: {
    redirectUris: [
      androidRedirectUri
    ]
  }

  isFallbackPublicClient: true

  requiredResourceAccess: [
    {
      resourceAppId: backendApp.appId
      resourceAccess: [
        {
          id: backendScopeId
          type: 'Scope'
        }
      ]
    }
  ]
}

resource apiSp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: backendApp.appId
}

output tenantId string = tenant().tenantId
output clientId string = app.appId
output objectId string = app.id
output androidRedirectUri string = androidRedirectUri
output backendClientId string = backendApp.appId
output backendObjectId string = backendApp.id
output requiredScope string = backendScopeValue
output expectedAudience string = backendApp.appId
