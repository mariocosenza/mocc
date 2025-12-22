extension 'br:mcr.microsoft.com/bicep/extensions/microsoftgraph/v1.0:0.1.9-preview'

targetScope = 'resourceGroup'

param apiAppDisplayName string = 'mocc-api'

resource apiApp 'Microsoft.Graph/applications@v1.0' = {
  displayName: apiAppDisplayName
  uniqueName: apiAppDisplayName 
  signInAudience: 'AzureADandPersonalMicrosoftAccount'
  api: {
    requestedAccessTokenVersion: 2
    oauth2PermissionScopes: [
      {
        id: guid(apiAppDisplayName, 'access_as_user')
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

resource apiSp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: apiApp.appId
}

output apiClientId string = apiApp.appId
output apiAudience string = 'api://${apiApp.appId}'
