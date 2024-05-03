metadata description = 'Creates an Azure Cosmos DB for NoSQL account.'
param name string
param location string = resourceGroup().location
param tags object = {}

param keyVaultName string
param cosmosDbConnectionStringSecretName string
param lzaResourceGroup string

module cosmos '../../cosmos/cosmos-account.bicep' = {
  name: 'cosmos-account'
  params: {
    name: name
    location: location
    tags: tags
    keyVaultName: keyVaultName
    kind: 'GlobalDocumentDB'
    lzaResourceGroup: lzaResourceGroup
    cosmosDbConnectionStringSecretName: cosmosDbConnectionStringSecretName
  }
}

output endpoint string = cosmos.outputs.endpoint
output id string = cosmos.outputs.id
output name string = cosmos.outputs.name
