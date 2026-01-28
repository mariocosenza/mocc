param tags object = {}
param location string = 'westeurope'

@secure()
@description('Firebase Project ID (service account)')
param firebaseProjectId string

@secure()
@description('Firebase Client Email (service account)')
param firebaseClientEmail string

@secure()
@description('Firebase Private Key (service account). Preserve header/footer and line breaks.')
param firebasePrivateKey string

resource namespace 'Microsoft.NotificationHubs/namespaces@2023-10-01-preview' = {
  name: 'moccnotifdev'
  location: location
  sku: { name: 'Free' }
  properties: {
    replicationRegion: 'None'
    zoneRedundancy: 'Disabled'
  }
}

resource notificationHub 'Microsoft.NotificationHubs/namespaces/notificationHubs@2023-10-01-preview' = {
  parent: namespace
  name: 'moccnotificationhub'
  location: location
  sku: { name: 'Free' }
  tags: tags
  properties: {
    name: 'moccnotificationhub'
    fcmV1Credential: {
      properties: {
        clientEmail: firebaseClientEmail
        privateKey: firebasePrivateKey
        projectId: firebaseProjectId
      }
    }
  }
}

resource fullAccessRule 'Microsoft.NotificationHubs/namespaces/notificationHubs/authorizationRules@2023-10-01-preview' = {
  parent: notificationHub
  name: 'FullAccess'
  properties: {
    rights: [
      'Send'
      'Listen'
      'Manage'
    ]
  }
}


output notificationHubNamespaceName string = namespace.name
output notificationHubName string = notificationHub.name
output notifHubSasPolicyName string = fullAccessRule.name
output notificationHubId string = notificationHub.id
output sendRuleId string = fullAccessRule.id
