param name string
param location string = resourceGroup().location
param tags object = {}
param storageSku string
param keyVaultName string
param lzaResourceGroup string
param laName string
param deploymentStorageConnectionStringSecretName string

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: true 
    encryption: {
      services: {
        blob: {
          keyType: 'Account'
          enabled: true
        }
        file: {
          keyType: 'Account'
          enabled: true
        }
      }
    }
  }
}

module fileShare './storage-fileshare.bicep' = {
  name: 'storage-fileshare'
  scope: resourceGroup()
  params: {
    storageAccountName: storage.name
    fileShareName: laName
  }
}

var blobStorageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storage.id, storage.apiVersion).keys[0].value}'
module keyvaultSecretConnectionString '../keyvault/keyvault-secret.bicep' = {
  name: '${storage.name}-connectionstring-deployment-keyvault'
  scope: resourceGroup(lzaResourceGroup)
  params: {
    keyVaultName: keyVaultName
    secretName: deploymentStorageConnectionStringSecretName
    secretValue: blobStorageConnectionString
  }
}

output storageName string = storage.name
output storageEndpoint string = storage.properties.primaryEndpoints.blob
output storageConnectionString string = blobStorageConnectionString
