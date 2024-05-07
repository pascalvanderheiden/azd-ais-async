param name string
param location string
param logicAppsIdentityName string
param myIpAddress string = ''
param myPrincipalId string = ''
param cosmosDbDatabaseName string
param cosmosDbContainerName string
param cosmosDbPartitionKeyPath string
param lzaResourceGroup string
param keyVaultName string

var defaultConsistencyLevel = 'Session'

resource logicAppsIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: logicAppsIdentityName
}

resource account 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: toLower(name)
  kind: 'GlobalDocumentDB'
  location: location
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: defaultConsistencyLevel
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: true
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
    publicNetworkAccess: 'Enabled' //to be able to run locally
    ipRules: [
      {
        ipAddressOrRange: myIpAddress
      }
    ]

  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-05-15' = {
  name: 'cosmosdb-database'
  parent: account
  properties:{
    resource: {
      id: cosmosDbDatabaseName
    }
  }
}

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2022-05-15' = {
  name: 'cosmosdb-container'
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

var CosmosDBBuiltInDataContributor = {
  id: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${account.name}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
}
resource sqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-11-15' = {
  name: guid(account.name, CosmosDBBuiltInDataContributor.id, logicAppsIdentityName)
  parent: account
  properties: {
    principalId: logicAppsIdentity.properties.principalId
    roleDefinitionId: CosmosDBBuiltInDataContributor.id
    scope: account.id
  }
}
resource sqlRoleAssignmentCurrentUser 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-11-15' = {
  name: guid(account.name,CosmosDBBuiltInDataContributor.id, myPrincipalId)
  parent: account
  properties: {
    principalId: myPrincipalId
    roleDefinitionId: CosmosDBBuiltInDataContributor.id
    scope: account.id
  }
}

var cosmosConnectionString = account.listConnectionStrings().connectionStrings[0].connectionString
module keyvaultSecretConnectionString '../keyvault/keyvault-secret.bicep' = {
  name: '${account.name}-connectionstring-deployment-keyvault'
  scope: resourceGroup(lzaResourceGroup)
  params: {
    keyVaultName: keyVaultName
    secretName: 'cosmos-connection-string'
    secretValue: cosmosConnectionString
  }
}

output cosmosDbEndPoint string = account.properties.documentEndpoint
