@description('The name of the virtual network')
param vnetName string = 'mocc-vnet'
param subnet1Name string = 'moccblobsubnet'

@description('The region where our virtual network will be deployed. Default is resource group location')
param location string = resourceGroup().location

@description('The tags that will be applied to the virtual network resource')
param tags object = {}

resource moccVnet 'Microsoft.Network/virtualNetworks@2025-01-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnet1Name
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
  resource subnet1 'subnets' existing = {
    name: subnet1Name
  }
}
  
@description('The resource ID of subnet 1')
output subnet1Id string = moccVnet::subnet1.id
