metadata description = 'Creates an Azure Cosmos DB account.'
param name string
param location string = resourceGroup().location
param tags object = {}

param cosmosDbConnectionStringSecretName string
param keyVaultName string
param lzaResourceGroup string

@allowed([ 'GlobalDocumentDB', 'MongoDB', 'Parse' ])
param kind string

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2022-08-15' = {
  name: name
  kind: kind
  location: location
  tags: union(tags, { 'azd-service-name': name })
  properties: {
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    apiProperties: (kind == 'MongoDB') ? { serverVersion: '4.2' } : {}
    capabilities: [ { name: 'EnableServerless' } ]
  }
}

module cosmosDbConnectionString '../../keyvault/keyvault-secret.bicep' = {
  name: 'cosmosdb-connection-string'
  scope: resourceGroup(lzaResourceGroup)
  params: {
    keyVaultName: keyVaultName
    secretName: cosmosDbConnectionStringSecretName
    secretValue: cosmos.listConnectionStrings().connectionStrings[0].connectionString
  }
}

output endpoint string = cosmos.properties.documentEndpoint
output id string = cosmos.id
output name string = cosmos.name
