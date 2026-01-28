param location string = resourceGroup().location

@description('Event Grid System Topic name')
param systemTopicName string = 'moccblobeventgrid'

@description('Existing Storage Account name (source of events)')
param storageAccountName string

resource storage 'Microsoft.Storage/storageAccounts@2025-06-01' existing = {
  name: storageAccountName
}

@description('Azure Function App ID (destination for events)')
param functionAppId string

@description('Whether to create the event subscription (requires function to exist)')
param createSubscription bool = true

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

resource eventSub 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2025-02-15' = if (createSubscription) {
  parent: systemTopic
  name: 'image-processed-sub'
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${functionAppId}/functions/generate_recipe_from_image'
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
      ]
      enableAdvancedFilteringOnArrays: true
      subjectBeginsWith: '/blobServices/default/containers/recipes-input/blobs/'
    }
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}


resource receiptSub 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2025-02-15' = if (createSubscription) {
  parent: systemTopic
  name: 'receipt-processed-sub'
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${functionAppId}/functions/process_receipt_image'
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
      ]
      enableAdvancedFilteringOnArrays: true
      subjectBeginsWith: '/blobServices/default/containers/uploads/blobs/receipts/'
    }
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}

output systemTopicId string = systemTopic.id
output systemTopicName string = systemTopic.name
output systemTopicResourceGroup string = resourceGroup().name
