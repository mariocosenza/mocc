param location string = resourceGroup().location

@description('Event Grid System Topic name')
param systemTopicName string = 'moccblobeventgrid'

@description('Existing Storage Account name (source of events)')
param storageAccountName string

resource storage 'Microsoft.Storage/storageAccounts@2025-06-01' existing = {
  name: storageAccountName
}

resource systemTopic 'Microsoft.EventGrid/systemTopics@2025-02-15' = {
  name: systemTopicName
  location: location
  tags: {
    tag: 'AzureEventGrid'
  }
  properties: {
    source: storage.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

output systemTopicId string = systemTopic.id
output systemTopicName string = systemTopic.name
output systemTopicResourceGroup string = resourceGroup().name
