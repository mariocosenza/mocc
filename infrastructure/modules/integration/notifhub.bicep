@description('The name of the Notification Hubs namespace.')
param namespaceName string

@description('The location in which the Notification Hubs resources should be deployed.')
param location string = resourceGroup().location

var hubName = 'MoccHub'

resource namespace 'Microsoft.NotificationHubs/namespaces@2023-09-01' = {
  name: namespaceName
  location: location
  sku: {
    name: 'Free'
  }
}

resource notificationHub 'Microsoft.NotificationHubs/namespaces/notificationHubs@2023-09-01' = {
  parent: namespace
  name: hubName
  location: location
  properties: {}
}
