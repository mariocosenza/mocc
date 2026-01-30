targetScope = 'resourceGroup'

param location string = 'westeurope'


param appLocation string = 'app'
param apiLocation string = ''
param appArtifactLocation string = 'build/web'

param backendUrl string = 'https://moccapim.azure-api.net/query' // Start with placeholder, update at runtime

module swa 'swa.bicep' = {
  name: 'deployStaticWebApp'
  params: {
    location: location
    name: 'mocc'
    appLocation: appLocation
    apiLocation: apiLocation
    appArtifactLocation: appArtifactLocation
    backendUrl: backendUrl
  }
}
