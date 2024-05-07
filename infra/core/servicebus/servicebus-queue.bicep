param name string
param queueName string

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' existing = {
  name: name
}

resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2022-01-01-preview' = {
  name: queueName
  parent: serviceBus
  properties: {
    lockDuration: 'PT5M'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    requiresSession: false
    defaultMessageTimeToLive: 'P10675199DT2H48M5.4775807S'
    deadLetteringOnMessageExpiration: false
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    maxDeliveryCount: 10
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
    enableExpress: false
  }
}

output serviceBusNamespaceName string =  serviceBus.name
output serviceBusNamespaceFullQualifiedName string = '${serviceBus.name}.servicebus.windows.net'
output serviceBusQueueName string = serviceBusQueue.name
