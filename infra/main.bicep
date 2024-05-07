targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Resource group name of the Integration Landingzone deployment.')
@metadata({
  azd: {
    type: 'string'
  }
})
param resourceGroupNameLza string

@description('Service Bus Namespace name of the Integration Landingzone deployment.')
@metadata({
  azd: {
    type: 'string'
  }
})
param serviceBusNamespaceLza string

@description('App Service Plan name of the Integration Landingzone deployment.')
@metadata({
  azd: {
    type: 'string'
  }
})
param appServicePlanLza string

@description('API Management name of the Integration Landingzone deployment.')
@metadata({
  azd: {
    type: 'string'
  }
})
param apiManagementNameLza string

@description('Key Vault name of the Integration Landingzone deployment.')
@metadata({
  azd: {
    type: 'string'
  }
})
param keyVaultNameLza string

@description('Application Insights name of the Integration Landingzone deployment.')
@metadata({
  azd: {
    type: 'string'
  }
})
param appInsightsNameLza string

@description('Logic Apps Virtual Network Subnet name (for non-ASEv3 Logic Apps) of the Integration Landingzone deployment.')
@metadata({
  azd: {
    type: 'string'
  }
})
param logicAppsSubnetNameLza string

@description('Azure Storage SKU.')
@allowed(['Standard_LRS','Standard_GRS','Standard_RAGRS','Standard_ZRS','Premium_LRS','Premium_ZRS','Standard_GZRS','Standard_RAGZRS'])
param storageSku string = 'Standard_LRS'

//Leave blank to use default naming conventions
param laIdentityName string = ''
param cosmosDbAccountName string = ''
param storageAccountName string = ''
param logicAppName string = ''
param myIpAddress string = ''
param myPrincipalId string = ''

// tags that should be applied to all resources.
var tags = { 'azd-env-name': environmentName }

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// vars specific to pattern
var cosmosDbDatabaseName = 'ods'
var cosmosDbContainerName = 'customer'
var cosmosDbPartitionKeyPath = '/customerId'
var cosmosDbConnectionStringSecretName = 'cosmosdb-connection-string'
var storageConnectionStringSecretName = 'storage-connection-string'
var serviceBusConnectionStringSecretName = 'servicebus-connection-string'
var serviceBusQueueName = 'customer'
var laOrchestrationName = 'orchestration-customer-wf'
var laProcessingName = 'processing-customer-wf'
var customerApiName = 'customer-api'
var customerApiDisplayName = 'Customer API'
var customerApiPath = 'customer'
var customerOpenApiSpecUrl = ''
var laName = !empty(logicAppName) ? logicAppName : '${abbrs.logicWorkflows}${resourceToken}'

// Organize resources in a resource group for your integration pattern
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

resource lzaResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: resourceGroupNameLza
}

module managedIdentityLa './core/security/managed-identity.bicep' = {
  name: 'managed-identity-la'
  scope: rg
  params: {
    name: !empty(laIdentityName) ? laIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}-la'
    location: location
    tags: tags
  }
}

module serviceBus './core/servicebus/servicebus-queue.bicep' = {
  name: 'servicebus'
  scope: lzaResourceGroup
  params: {
    name: serviceBusNamespaceLza
    location: location
    tags: tags
    laManagedIdentityName: managedIdentityLa.outputs.managedIdentityName
    queueName: serviceBusQueueName
  }
}

module cosmosDb './core/database/cosmos.bicep' = {
  name: 'cosmosdb'
  scope: rg
  params: {
    name: !empty(cosmosDbAccountName) ? cosmosDbAccountName : '${abbrs.documentDBDatabaseAccounts}${resourceToken}'
    location: location
    lzaResourceGroup: lzaResourceGroup.name
    logicAppsIdentityName: managedIdentityLa.outputs.managedIdentityName
    myIpAddress: myIpAddress
    myPrincipalId: myPrincipalId
    cosmosDbDatabaseName: cosmosDbDatabaseName
    cosmosDbContainerName: cosmosDbContainerName
    cosmosDbPartitionKeyPath: cosmosDbPartitionKeyPath
    keyVaultName: keyVaultNameLza
  }
}

module storage './core/storage/storage.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    storageSku: storageSku
    fileShareName: laName
  }
}

module logicApp './core/host/logic-apps.bicep' = {
  name: 'logicapp'
  scope: rg
  params: {
    name: laName
    location: location
    tags: tags
    keyVaultName: keyVaultNameLza
    lzaResourceGroup: lzaResourceGroup.name
    storageConnectionStringSecretName: storageConnectionStringSecretName
    appInsightName: appInsightsNameLza
    laManagedIdentityName: managedIdentityLa.outputs.managedIdentityName
    aspName: appServicePlanLza
    logicAppsSubnetNameLza: logicAppsSubnetNameLza
    storageConnectionString: storage.outputs.storageConnectionString
  }
}

module customerApi './core/gateway/apim-api.bicep' = {
  name: 'customer-api'
  scope: lzaResourceGroup
  params: {
    name: customerApiName
    displayName: customerApiDisplayName
    path: customerApiPath
    openApiSpecUrl: customerOpenApiSpecUrl
    apimName: apiManagementNameLza
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
