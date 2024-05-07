param name string
param location string = resourceGroup().location
param tags object = {}
param lzaResourceGroup string
@secure()
param storageConnectionString string
@secure()
param serviceBusConnectionString string
param serviceBusNamespaceName string
@secure()
param cosmosDbConnectionString string
param cosmosDbName string
param appInsightName string
param aspName string
param laManagedIdentityName string
param vnetNameLza string
param logicAppsSubnetNameLza string
param allowedOrigins array = []

resource appInsight 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightName
  scope: resourceGroup('${lzaResourceGroup}')
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' existing = {
  name: aspName
  scope: resourceGroup('${lzaResourceGroup}')
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: vnetNameLza
  scope: resourceGroup('${lzaResourceGroup}')
  resource subnet 'subnets@2022-01-01' existing = {
    name: logicAppsSubnetNameLza
  }
}

resource managedIdentityLa 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: laManagedIdentityName
}

resource logicApp 'Microsoft.Web/sites@2022-03-01' = {
  name: name
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityLa.id}': {}
    }
  }
  tags: union(tags, { 'azd-service-name': name })
  properties: {
      httpsOnly: true
      vnetRouteAllEnabled: true
      vnetContentShareEnabled: true
      storageAccountRequired: true
      publicNetworkAccess: 'Disabled'
      virtualNetworkSubnetId: vnet::subnet.id
      serverFarmId: appServicePlan.id
      clientAffinityEnabled: false
  }
}

resource logicAppConfig 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: logicApp
  name: 'web'
  properties: {
      numberOfWorkers: 1
      use32BitWorkerProcess: false
      cors: {
        allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
      }
      appSettings: [
          { name: 'APP_KIND', value: 'workflowApp' }
          { name: 'APPINSIGHTS_INSTRUMENTATIONKEY', value: appInsight.properties.InstrumentationKey }
          { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsight.properties.ConnectionString }
          { name: 'AzureFunctionsJobHost__extensionBundle__id', value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows' }
          { name: 'AzureFunctionsJobHost__extensionBundle__version', value: '[1.*, 2.0.0)' }
          { name: 'AzureWebJobsStorage', value: storageConnectionString }
          { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
          { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'node' }
          { name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING', value: storageConnectionString }
          { name: 'WEBSITE_CONTENTSHARE', value: toLower('${name}') }
          { name: 'WEBSITE_NODE_DEFAULT_VERSION', value: '~16' }
          { name: 'WEBSITE_VNET_ROUTE_ALL', value: '1'}
          { name: 'WEBSITE_DNS_SERVER', value: '168.63.129.16'}
          { name: 'Workflows.my-workflow.FlowState', value: 'Enabled' }
          { name: 'serviceBus_name', value: serviceBusNamespaceName }
          { name: 'serviceBus_connectionString', value: serviceBusConnectionString }
          { name: 'cosmosDb_name', value: cosmosDbName }
          { name: 'cosmosDb_connectionString', value: cosmosDbConnectionString }
      ]
  }
}

