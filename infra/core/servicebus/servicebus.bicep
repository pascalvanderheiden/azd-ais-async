param name string
param location string = resourceGroup().location
param tags object = {}
param laManagedIdentityName string

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' existing = {
  name: name
}

resource laManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: laManagedIdentityName
}

module sbReceiverRoleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'sb-la-receiver-roleAssignment'
  params: {
    principalId: laManagedIdentity.properties.principalId
    roleName: 'Service Bus Data Receiver'
    targetResourceId: serviceBus.id
    deploymentName: 'sb-la-roleAssignment-DataReceiver'
  }
}

module sbSenderRoleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'sb-la-sender-roleAssignment'
  params: {
    principalId: laManagedIdentity.properties.principalId
    roleName: 'Service Bus Data Sender'
    targetResourceId: serviceBus.id
    deploymentName: 'sb-la-roleAssignment-DataSender'
  }
}

output serviceBusNamespaceName string =  serviceBus.name
output serviceBusNamespaceFullQualifiedName string = '${serviceBus.name}.servicebus.windows.net'
