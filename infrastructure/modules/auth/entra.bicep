targetScope = 'tenant'
extension 'br:mcr.microsoft.com/bicep/extensions/microsoftgraph/v1.0:0.1.9-preview'

param appName string = 'mocc-flutter-swa'
param swaUrl string = 'https://mocc.azurestaticapps.net'
param localUrl string = 'http://localhost:4280'

@description('Android applicationId / package name, e.g. com.yourcompany.mocc')
param androidPackageName string
//TODO Generate Base64 URL
@description('Base64URL-encoded signing certificate signature from Azure Portal "Android redirect URI" (the part after the package name).')
param androidSignatureHash string

var androidRedirectUri = 'msauth://${androidPackageName}/${androidSignatureHash}'

resource app 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: appName
  displayName: appName
  signInAudience: 'AzureADMyOrg'

  spa: {
    redirectUris: [
      '${swaUrl}/'
      '${localUrl}/'
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
