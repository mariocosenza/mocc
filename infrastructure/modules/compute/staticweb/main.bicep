targetScope = 'resourceGroup'

param location string = 'westeurope'

@secure()
param repositoryToken string

param appLocation string = 'app'
param apiLocation string = ''
param appArtifactLocation string = 'build/web'

param backendUrl string = 'https://moccapim.azure-api.net' // Start with placeholder, update at runtime

module swa 'swa.bicep' = {
  name: 'deployStaticWebApp'
  params: {
    location: location
    name: 'mocc'
    repositoryToken: repositoryToken
    appLocation: appLocation
    apiLocation: apiLocation
    appArtifactLocation: appArtifactLocation
    backendUrl: backendUrl
  }
}
