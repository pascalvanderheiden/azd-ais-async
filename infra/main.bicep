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

@description('Azure Frontdoor name of the Integration Landingzone deployment.')
@metadata({
  azd: {
    type: 'string'
  }
})
param frontDoorNameLza string

//Leave blank to use default naming conventions
param laIdentityName string = ''

// tags that should be applied to all resources.
var tags = { 'azd-env-name': environmentName }

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var apiServiceName = 'async-api'

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
  name: 'managed-identity-apim'
  scope: rg
  params: {
    name: !empty(laIdentityName) ? laIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}-la'
    location: location
    tags: tags
  }
}

module serviceBus './core/servicebus/servicebus.bicep' = {
  name: 'servicebus'
  scope: lzaResourceGroup
  params: {
    name: serviceBusNamespaceLza
    location: location
    tags: tags
    laManagedIdentityName: managedIdentityLa.outputs.managedIdentityName
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output FRONTDOOR_GATEWAY_ENDPOINT_NAME string = frontDoor.outputs.frontDoorProxyEndpointHostName
