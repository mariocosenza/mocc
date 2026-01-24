param location string
param name string
param backendUrl string

@secure()
param repositoryToken string

param appLocation string = 'app'
param apiLocation string = ''
param appArtifactLocation string = 'build/web'

resource staticSite 'Microsoft.Web/staticSites@2025-03-01' = {
  name: name
  location: location
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    provider: 'Custom'
    repositoryUrl: 'https://github.com/mariocosenza/mocc'
    branch: 'main'
    repositoryToken: repositoryToken
    buildProperties: {
      appLocation: appLocation
      apiLocation: apiLocation
      appArtifactLocation: appArtifactLocation
    }
  }
}

resource staticSiteSettings 'Microsoft.Web/staticSites/config@2022-03-01' = {
  parent: staticSite
  name: 'appsettings'
  properties: {
    MOCC_API_URL: backendUrl
  }
}
