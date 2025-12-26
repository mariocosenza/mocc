param location string = resourceGroup().location

param systemTopicName string = 'moccblobeventgrid'
param storageAccountName string 

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource systemTopic 'Microsoft.EventGrid/systemTopics@2022-06-15' = {
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
