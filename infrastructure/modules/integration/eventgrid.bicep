param location string = resourceGroup().location

param systemTopicName string = 'moccblobeventgrid'
param storageAccountName string = 'moccstorage'


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
