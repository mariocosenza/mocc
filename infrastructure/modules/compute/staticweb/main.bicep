targetScope = 'subscription'

param location string = 'westeurope'

@secure()
param repositoryToken string

param appLocation string = 'app'
param apiLocation string = ''
param appArtifactLocation string = 'build/web'

param enterpriseGradeCdnStatus string = 'Disabled'

var rgName = 'mocc-${location}-swa'

resource websiteResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: rgName
  location: location
}

module swa 'swa.bicep' = {
  name: 'deployStaticWebApp'
  scope: resourceGroup(rgName)
  params: {
    location: location
    name: 'mocc'
    repositoryToken: repositoryToken
    appLocation: appLocation
    apiLocation: apiLocation
    appArtifactLocation: appArtifactLocation
    enterpriseGradeCdnStatus: enterpriseGradeCdnStatus
  }
  dependsOn: [
    websiteResourceGroup
  ]
}
