param tags object = {}
param location string = 'westeurope'

resource namespace 'Microsoft.NotificationHubs/namespaces@2023-10-01-preview' = {
  name: 'moccnotifdev'
  location: location
  sku: {
    name: 'Free'
  }
  properties: {
    replicationRegion: 'None'
    zoneRedundancy: 'Disabled'
  }
}

resource namespaceName_notificationHub 'Microsoft.NotificationHubs/namespaces/notificationHubs@2023-10-01-preview' = {
  parent: namespace
  name: 'moccnotificationhub'
  location: location
  sku: {
    name: 'Free'
  }
  tags: tags
  properties: {
    name: 'moccnotificationhub'
  }
}
