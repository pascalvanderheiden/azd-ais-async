targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Resource group name of the Integration Landingzone deployment.')
param resourceGroupNameLza string = ''

@description('Service Bus Namespace name of the Integration Landingzone deployment.')
param serviceBusNamespaceNameLza string = ''

@description('Storage Account name of the Integration Landingzone deployment.')
param storageAccountNameLza string = ''

@description('App Service Plan name of the Integration Landingzone deployment.')
param appServicePlanNameLza string = ''

@description('API Management name of the Integration Landingzone deployment.')
param apiManagementNameLza string = ''

@description('Key Vault name of the Integration Landingzone deployment.')
param keyVaultNameLza string = ''

@description('Application Insights name of the Integration Landingzone deployment.')
param appInsightsNameLza string = ''

@description('Logic Apps Virtual Network Subnet name (for non-ASEv3 Logic Apps) of the Integration Landingzone deployment.')
param logicAppsSubnetNameLza string = ''

@description('Private Endpoint Virtual Network Subnet name of the Integration Landingzone deployment.')
param peSubnetNameLza string = ''

@description('Virtual Network name (for non-ASEv3 Logic Apps) of the Integration Landingzone deployment.')
param vnetNameLza string = ''

@description('Deploy to ASEv3')
param deployToAse bool = false

//Leave blank to use default naming conventions
param laIdentityName string = ''
param cosmosDbAccountName string = ''
param logicAppsName string = ''
param myIpAddress string = ''
//param myPrincipalId string = ''

// tags that should be applied to all resources.
var tags = { 'azd-env-name': environmentName }

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// vars specific to pattern
var laName = !empty(logicAppsName) ? logicAppsName : '${abbrs.logicWorkflows}${resourceToken}'
var laOrchestrationCustomerWorkflow = 'orchestration-customer-wf'
var laOrchestrationCustomerWorkflowTrigger = 'When_a_HTTP_request_is_received'
var laOrchestrationCustomerWorkflowApiVersionNamedValue = 'orchestration-customer-wf-api-version'
var laOrchestrationCustomerWorkflowSpNamedValue = 'orchestration-customer-wf-sp'
var laOrchestrationCustomerWorkflowSvNamedValue = 'orchestration-customer-wf-sv'
var laOrchestrationCustomerWorkflowSigNamedValue = 'orchestration-customer-wf-sig'
var cosmosDbDatabaseName = 'ods'
var cosmosDbContainerName = 'customer'
var cosmosDbPartitionKeyPath = '/customerId'
var cosmosDbConnectionStringSecretName = 'cosmosdb-connection-string'
var storageConnectionStringSecretName = 'storage-connection-string'
var serviceBusConnectionStringSecretName = 'servicebus-connection-string'
var serviceBusQueueName = 'customer'
var customerApiName = 'customer-api'
var customerApiDisplayName = 'Customer API'
var customerApiPath = '' // Leave blank to use path from OpenAPI definition
var customerApiPolicyRaw = loadTextContent('../infra/core/gateway/policies/api-policy.xml')
var apimPolicyLaName = replace(customerApiPolicyRaw, '__laName__', laName)
var apimPolicyWorkflowName = replace(apimPolicyLaName, '__workflowName__', laOrchestrationCustomerWorkflow)
var apimPolicyWorkflowTrigger = replace(apimPolicyWorkflowName, '__workflowTrigger__', laOrchestrationCustomerWorkflowTrigger)
var apimPolicyWorkflowApiVersion = replace(apimPolicyWorkflowTrigger, '__api-version__', laOrchestrationCustomerWorkflowApiVersionNamedValue)
var apimPolicyWorkflowSp = replace(apimPolicyWorkflowApiVersion, '__sp__', laOrchestrationCustomerWorkflowSpNamedValue)
var apimPolicyWorkflowSv = replace(apimPolicyWorkflowSp, '__sv__', laOrchestrationCustomerWorkflowSvNamedValue)
var apimPolicyWorkflowSig = replace(apimPolicyWorkflowSv, '__sig__', laOrchestrationCustomerWorkflowSigNamedValue)
var apimAPIPolicyReplaced = apimPolicyWorkflowSig
var customerApiDefinition = '../infra/core/gateway/openapi/customer_openapi_v3.yaml'
var customerNamedValues = [
  {
    key: laOrchestrationCustomerWorkflowApiVersionNamedValue
    value: 'placeholder'
    secret: false
  }
  {
    key: laOrchestrationCustomerWorkflowSpNamedValue
    value: 'placeholder'
    secret: false
  }
  {
    key: laOrchestrationCustomerWorkflowSvNamedValue
    value: 'placeholder'
    secret: false
  }
  {
    key: laOrchestrationCustomerWorkflowSigNamedValue
    value: 'placeholder'
    secret: true
  }
]
var logicAppsPrivateDnsZoneName = 'privatelink.azurewebsites.net'
var cosmosDbPrivateDnsZoneName = 'privatelink.documents.azure.com'
var privateDnsZoneNames = [
  logicAppsPrivateDnsZoneName
  cosmosDbPrivateDnsZoneName
]

// Organize resources in a resource group for your integration pattern
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

resource lzaResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: resourceGroupNameLza
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultNameLza
  scope: resourceGroup(resourceGroupNameLza)
}

module dnsDeployment './core/networking/dns.bicep' = [for privateDnsZoneName in privateDnsZoneNames: {
  name: 'dns-deployment-${privateDnsZoneName}'
  scope: rg
  params: {
    name: privateDnsZoneName
    tags: tags
  }
}]

module managedIdentityLa './core/security/managed-identity.bicep' = {
  name: 'managed-identity-la'
  scope: rg
  params: {
    name: !empty(laIdentityName) ? laIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}-la'
    location: location
    tags: tags
  }
}

module laRoleAssignment './core/roleassignments/roleassignment.bicep' = {
  name: 'kv-la-roleAssignment'
  scope: lzaResourceGroup
  params: {
    principalId: managedIdentityLa.outputs.managedIdentityPrincipalId
    roleName: 'Key Vault Secrets User'
    targetResourceId: keyVault.id
    deploymentName: 'kv-la-roleAssignment-SecretsUser'
  }
}

module serviceBus './core/servicebus/servicebus-queue.bicep' = {
  name: 'servicebus'
  scope: lzaResourceGroup
  params: {
    name: serviceBusNamespaceNameLza
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
    myIpAddress: myIpAddress
    cosmosDbDatabaseName: cosmosDbDatabaseName
    cosmosDbContainerName: cosmosDbContainerName
    cosmosDbPartitionKeyPath: cosmosDbPartitionKeyPath
    keyVaultName: keyVaultNameLza
    cosmosDbConnectionStringSecretName: cosmosDbConnectionStringSecretName
    vnetNameLza: vnetNameLza
    cosmosDbPrivateEndpointName: '${abbrs.documentDBDatabaseAccounts}${abbrs.privateEndpoints}${resourceToken}'
    cosmosDbPrivateDnsZoneName: logicAppsPrivateDnsZoneName
    peSubnetNameLza: peSubnetNameLza
  }
}

module storage './core/storage/storage-fileshare.bicep' = {
  name: 'storage-fileshare'
  scope: lzaResourceGroup
  params: {
    storageAccountName: storageAccountNameLza
    fileShareName: laName
  }
}

module logicApp './core/host/logic-apps.bicep' = {
  name: 'logicapp'
  scope: rg
  params: {
    name: laName
    location: location
    tags: union(tags, { 'azd-service-name': 'api' })
    lzaResourceGroup: lzaResourceGroup.name
    appInsightName: appInsightsNameLza
    laManagedIdentityName: managedIdentityLa.outputs.managedIdentityName
    aspName: appServicePlanNameLza
    vnetNameLza: vnetNameLza
    logicAppsSubnetNameLza: logicAppsSubnetNameLza
    storageConnectionString: keyVault.getSecret(storageConnectionStringSecretName)
    serviceBusNamespaceName: serviceBusNamespaceNameLza
    serviceBusConnectionString: keyVault.getSecret(serviceBusConnectionStringSecretName)
    cosmosDbName: cosmosDb.outputs.cosmosDbAccountName
    cosmosDbConnectionString: keyVault.getSecret(cosmosDbConnectionStringSecretName)
    myIpAddress: myIpAddress
    logicAppsPrivateEndpointName: '${abbrs.logicWorkflows}${abbrs.privateEndpoints}${resourceToken}'
    logicAppsPrivateDnsZoneName: logicAppsPrivateDnsZoneName
    peSubnetNameLza: peSubnetNameLza
  }
  dependsOn: [
    managedIdentityLa
    laRoleAssignment
    cosmosDb
    storage
  ]
}

module customerApi './core/gateway/apim-api.bicep' = {
  name: 'customer-api'
  scope: lzaResourceGroup
  params: {
    name: customerApiName
    displayName: customerApiDisplayName
    path: customerApiPath
    policy: apimAPIPolicyReplaced
    definition: loadTextContent(customerApiDefinition)
    apimName: apiManagementNameLza
    logicAppsName: logicApp.outputs.logicAppsName
    logicAppsId: logicApp.outputs.logicAppsId
    logicAppsDefaultHostname: logicApp.outputs.logicAppsDefaultHostname
    namedValues: customerNamedValues
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output RESOURCE_GROUP_NAME string = rg.name
output LOGIC_APPS_NAME string = logicApp.outputs.logicAppsName
output COSMOS_DB_ACCOUNT_NAME string = cosmosDb.outputs.cosmosDbAccountName
output LA_ORCHESTRATION_CUSTOMER_WF_NAME string = laOrchestrationCustomerWorkflow
output LA_ORCHESTRATION_CUSTOMER_WF_TRIGGER string = laOrchestrationCustomerWorkflowTrigger
output LA_ORCHESTRATION_CUSTOMER_WF_API_VERSION_NV string = laOrchestrationCustomerWorkflowApiVersionNamedValue
output LA_ORCHESTRATION_CUSTOMER_WF_SP_NV string = laOrchestrationCustomerWorkflowSpNamedValue
output LA_ORCHESTRATION_CUSTOMER_WF_SV_NV string = laOrchestrationCustomerWorkflowSvNamedValue
output LA_ORCHESTRATION_CUSTOMER_WF_SIG_NV string = laOrchestrationCustomerWorkflowSigNamedValue
