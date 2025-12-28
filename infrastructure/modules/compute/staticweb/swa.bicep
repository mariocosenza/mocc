param location string
param name string

@secure()
param repositoryToken string

param appLocation string = 'app'
param apiLocation string = ''
param appArtifactLocation string = 'build/web'
param enterpriseGradeCdnStatus string = 'Disabled'

resource staticSite 'Microsoft.Web/staticSites@2025-03-01' = {
  name: name
  location: location
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    provider: 'GitHub'
    repositoryUrl: 'https://github.com/mariocosenza/mocc'
    branch: 'main'
    repositoryToken: repositoryToken
    buildProperties: {
      appLocation: appLocation
      apiLocation: apiLocation
      appArtifactLocation: appArtifactLocation
    }
    enterpriseGradeCdnStatus: enterpriseGradeCdnStatus
  }
}
