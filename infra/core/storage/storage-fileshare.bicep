param name string
param fileShareName string

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: name
}

resource fileShareService 'Microsoft.Storage/storageAccounts/fileServices@2023-04-01' existing = {
  name: '${storage.name}/default'
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: fileShareName
  parent: fileShareService
}

output storageName string = storage.name
output storageEndpoint string = storage.properties.primaryEndpoints.blob
