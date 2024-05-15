param name string
param location string
param tags object = {}
param myIpAddress string = ''
param cosmosDbDatabaseName string
param cosmosDbContainerName string
param cosmosDbPartitionKeyPath string
param lzaResourceGroup string
param keyVaultName string
param cosmosDbConnectionStringSecretName string
param vnetNameLza string
param cosmosDbPrivateEndpointName string
param cosmosDbPrivateDnsZoneName string
param peSubnetNameLza string

var defaultConsistencyLevel = 'Session'

resource account 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: toLower(name)
  kind: 'GlobalDocumentDB'
  location: location
  tags: union(tags, { 'azd-service-name': name })
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: defaultConsistencyLevel
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    disableKeyBasedMetadataWriteAccess: true
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    publicNetworkAccess: 'Enabled'
    ipRules: [
      {
        ipAddressOrRange: myIpAddress //for local development
      }
    ]
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-05-15' = {
  name: cosmosDbDatabaseName
  parent: account
  tags: union(tags, { 'azd-service-name': cosmosDbDatabaseName })
  properties:{
    resource: {
      id: cosmosDbDatabaseName
    }
  }
}

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2022-05-15' = {
  name: cosmosDbContainerName
  parent: database
  properties:{
    resource: {
      id: cosmosDbContainerName
      partitionKey: {
        paths: [
          cosmosDbPartitionKeyPath
        ]
        kind: 'Hash'
      }
    }
  }
}

var cosmosDbConnectionString = account.listConnectionStrings().connectionStrings[0].connectionString
module keyvaultSecretConnectionString '../keyvault/keyvault-secret.bicep' = {
  name: '${account.name}-connectionstring-deployment-keyvault'
  scope: resourceGroup(lzaResourceGroup)
  params: {
    keyVaultName: keyVaultName
    secretName: cosmosDbConnectionStringSecretName
    secretValue: cosmosDbConnectionString
  }
}

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${account.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'Sql'
    ]
    dnsZoneName: cosmosDbPrivateDnsZoneName
    name: cosmosDbPrivateEndpointName
    subnetName: peSubnetNameLza
    privateLinkServiceId: account.id
    vNetName: vnetNameLza
    location: location
    lzaResourceGroup: lzaResourceGroup
  }
}

output cosmosDbAccountName string = account.name
output cosmosDbEndPoint string = account.properties.documentEndpoint
