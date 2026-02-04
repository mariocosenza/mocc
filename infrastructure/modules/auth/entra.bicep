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
param androidSignatureHash string = '1%2FpNWOaXQYYPE8oUh%2BgnFURnVeE%3D'

@description('OAuth2 scope value exposed by the backend API (used in scp).')
param backendScopeValue string = 'access_as_user'

var androidRedirectUri = 'msauth://${androidPackageName}/${androidSignatureHash}'
var backendScopeId = guid(backendAppName, 'scope', backendScopeValue)
var backendAppIdUri = 'api://${backendAppName}'

resource backendApp 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: backendAppName
  displayName: backendAppName
  signInAudience: 'AzureADandPersonalMicrosoftAccount'
  identifierUris: [
    backendAppIdUri
  ]
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
        value: backendScopeValue
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
      '${swaUrl}/auth.html'
      '${localUrl}/auth.html'
      '${localUrl8000}/auth.html'
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
    {
      resourceAppId: '00000003-0000-0000-c000-000000000000'
      resourceAccess: [
        {
          id: '64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0' // User.Read
          type: 'Scope'
        }
        {
          id: '7427e0e9-2fba-42fe-b0c0-848c9e6a8182' // Offline_access
          type: 'Scope'
        }
        {
          id: '37f7f235-527c-4136-accd-4a02d197296e' // User.ReadBasic.All
          type: 'Scope'
        }
        {
          id: '14dad69e-099b-42c9-810b-d002981feec1' // Profile
          type: 'Scope'
        }
        {
          id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read.All
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
output backendAppIdUri string = backendAppIdUri
output requiredScope string = backendScopeValue
output expectedAudience string = backendAppIdUri
