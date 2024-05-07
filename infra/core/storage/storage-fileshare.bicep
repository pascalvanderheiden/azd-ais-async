param storageAccountName string
param fileShareName string

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storage.name}/default/${fileShareName}'
}

output storageName string = storage.name
output storageEndpoint string = storage.properties.primaryEndpoints.blob
