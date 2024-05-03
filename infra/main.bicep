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

//Leave blank to use default naming conventions
param laIdentityName string = ''
param cosmosDbAccountName string = ''

// tags that should be applied to all resources.
var tags = { 'azd-env-name': environmentName }

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// vars specific to pattern
var cosmosDbDatabaseName = 'customers'
var cosmosDbConnectionStringSecretName = 'cosmosdb-connection-string'
var storageConnectionStringSecretName = 'storage-connection-string'
var serviceBusQueueName = 'customers'
var laOrchestrationName = 'orchestration-customer-wf'
var laProcessingName = 'processing-customer-wf'
var cosmosDbContainerDef = [
  {
    name: 'customers'
    partitionKeyPath: '/id'
  }
]
var customerApiName = 'customer-api'
var customerApiDisplayName = 'Customer API'
var customerApiPath = 'customer'
var customerOpenApiSpecUrl = ''

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

module cosmosDb './core/database/cosmos/sql/cosmos-sql-db.bicep' = {
  name: 'cosmosdb'
  scope: rg
  params: {
    accountName: !empty(cosmosDbAccountName) ? cosmosDbAccountName : '${abbrs.documentDBDatabaseAccounts}${resourceToken}'
    databaseName: cosmosDbDatabaseName
    location: location
    tags: tags
    keyVaultName: keyVaultNameLza
    lzaResourceGroup: lzaResourceGroup.name
    cosmosDbConnectionStringSecretName: cosmosDbConnectionStringSecretName
    containers: cosmosDbContainerDef
    principalIds: [
      managedIdentityLa.outputs.managedIdentityPrincipalId
    ]
  }
}

module logicApp './core/host/logic-apps.bicep' = {
  name: 'logicapp'
  scope: rg
  params: {
    name: customerApiName
    location: location
    tags: tags
    keyVaultName: keyVaultNameLza
    lzaResourceGroup: lzaResourceGroup.name
    storageConnectionStringSecretName: storageConnectionStringSecretName
    appInsightName: appInsightsNameLza
    laManagedIdentityName: managedIdentityLa.outputs.managedIdentityName
    aspName: appServicePlanLza

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
