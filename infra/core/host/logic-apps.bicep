param name string
param location string = resourceGroup().location
param tags object = {}
param lzaResourceGroup string
param keyVaultName string
param storageConnectionStringSecretName string
param appInsightName string
param aspName string
param laManagedIdentityName string

resource appInsight 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightName
  scope: resourceGroup(lzaResourceGroup)
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' existing = {
  name: aspName
  scope: resourceGroup(lzaResourceGroup)
}

resource managedIdentityLa 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: laManagedIdentityName
}


resource logicApp 'Microsoft.Web/sites@2021-02-01' = {
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
      siteConfig: {
          appSettings: [
              { name: 'APP_KIND', value: 'workflowApp' }
              { name: 'APPINSIGHTS_INSTRUMENTATIONKEY', value: appInsight.properties.InstrumentationKey }
              { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsight.properties.ConnectionString }
              { name: 'AzureFunctionsJobHost__extensionBundle__id', value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows' }
              { name: 'AzureFunctionsJobHost__extensionBundle__version', value: '[1.*, 2.0.0)' }
              { name: 'AzureWebJobsStorage', value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${storageConnectionStringSecretName}/)' }
              { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
              { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'node' }
              { name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING', value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${storageConnectionStringSecretName}/)' }
              { name: 'WEBSITE_CONTENTSHARE', value: toLower('${name}') }
              { name: 'WEBSITE_NODE_DEFAULT_VERSION', value: '~16' }
              { name: 'WEBSITE_VNET_ROUTE_ALL', value: '1'}
              { name: 'WEBSITE_DNS_SERVER', value: '168.63.129.16'}
              { name: 'Workflows.my-workflow.FlowState', value: 'Enabled' }
          ]
          use32BitWorkerProcess: true
      }
      serverFarmId: appServicePlan.id
      clientAffinityEnabled: false
  }
}
