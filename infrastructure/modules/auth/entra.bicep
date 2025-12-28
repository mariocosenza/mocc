targetScope = 'tenant'
extension 'br:mcr.microsoft.com/bicep/extensions/microsoftgraph/v1.0:0.1.9-preview'

param appName string = 'mocc-flutter-swa'
param swaUrl string = 'https://mocc.azurestaticapps.net'
param localUrl string = 'http://localhost:4280'

resource spaApp 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: appName
  displayName: appName
  signInAudience: 'AzureADMyOrg'
  spa: {
    redirectUris: [
      '${swaUrl}/'
      '${localUrl}/'
    ]
  }
}

// 3. Outputs
output clientId string = spaApp.appId
output objectId string = spaApp.id
