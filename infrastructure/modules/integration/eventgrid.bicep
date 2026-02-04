param location string = resourceGroup().location

@description('Event Grid System Topic name')
param systemTopicName string = 'moccblobeventgrid'

@description('Existing Storage Account name (source of events)')
param storageAccountName string


@description('Azure Function App ID (destination for events)')
param functionAppId string

@description('Whether to create the event subscription (requires function to exist)')
param createSubscription bool = true

@description('Azure Container Apps Environment ID')
param acaId string

@description('Function App Principal ID (for role assignment)')
param functionPrincipalId string

var eventGridDataSenderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'd5a91429-5739-47e2-a06b-3470a27159e7') // EventGrid Data Sender


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


resource socialSub 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2025-02-15' = if (createSubscription) {
  parent: systemTopic
  name: 'social-posts-final-created-sub'
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${functionAppId}/functions/filter_social_image'
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
      ]
      subjectBeginsWith: '/blobServices/default/containers/social/blobs/posts/'
    }
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}

resource labelSub 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2025-02-15' = if (createSubscription) {
  parent: systemTopic
  name: 'label-processed-sub'
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${functionAppId}/functions/process_product_label'
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
      ]
      enableAdvancedFilteringOnArrays: true
      subjectBeginsWith: '/blobServices/default/containers/uploads/blobs/product-labels/'
    }
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}

resource postCommentTopic 'Microsoft.EventGrid/topics@2025-02-15' = if (createSubscription) {
  name: 'moccpostcomments'
  location: location
  properties: {
    inputSchema: 'CloudEventSchemaV1_0'
    publicNetworkAccess: 'Enabled'
  }
}

resource postComeentsSub 'Microsoft.EventGrid/topics/eventSubscriptions@2025-02-15' = if (createSubscription) {
  parent: postCommentTopic
  name: 'newComment'
  properties: {
    destination: {
      endpointType: 'AzureFunction'
      properties: {
        resourceId: '${functionAppId}/functions/process_new_comment'
      }
    }
    filter: {
      isSubjectCaseSensitive: false
    }
    retryPolicy: {
      maxDeliveryAttempts: 10
      eventTimeToLiveInMinutes: 1440
    }
  }
}


resource raFunc 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(postCommentTopic.id, functionPrincipalId, eventGridDataSenderRoleId)
  properties: {
    roleDefinitionId: eventGridDataSenderRoleId
    principalId: functionPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource raAca 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(postCommentTopic.id, acaId, eventGridDataSenderRoleId)
  properties: {
    roleDefinitionId: eventGridDataSenderRoleId
    principalId: acaId
    principalType: 'ServicePrincipal'
  }
}

output systemTopicId string = systemTopic.id
output customTopicId string = postCommentTopic.id
output systemTopicName string = systemTopic.name
output systemTopicResourceGroup string = resourceGroup().name
