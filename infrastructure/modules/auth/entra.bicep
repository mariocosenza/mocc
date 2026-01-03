targetScope = 'tenant'
extension 'br:mcr.microsoft.com/bicep/extensions/microsoftgraph/v1.0:0.1.9-preview'

param appName string = 'mocc-flutter-swa'
param swaUrl string = 'https://mocc.azurestaticapps.net'
param localUrl string = 'http://localhost:4280'
param localUrl8000 string = 'http://localhost:8000'

@description('Android applicationId / package name, e.g. com.yourcompany.mocc')
param androidPackageName string = 'it.unisa.mocc'

@description('Base64 encoded signing certificate signature')
param androidSignatureHash string = 'GhA+HfJcocF4G9Oe5GK90xDBzHo='

var androidRedirectUri = 'msauth://${androidPackageName}/${androidSignatureHash}'

resource app 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: appName
  displayName: appName
  signInAudience: 'AzureADMyOrg'

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
}

output clientId string = app.appId
output objectId string = app.id
output androidRedirectUri string = androidRedirectUri
