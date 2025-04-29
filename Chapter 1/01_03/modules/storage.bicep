// modules/storage.bicep - Storage account module
// Demonstrates resource loops for creating multiple storage accounts

@description('Location for all resources.')
param location string

@description('Base name for resources')
param baseName string

@description('Common tags for all resources')
param tags object

@description('Number of storage accounts to deploy')
param storageAccountCount int = 1

// RESOURCE LOOPS - Creating multiple storage accounts
resource storageAccounts 'Microsoft.Storage/storageAccounts@2022-09-01' = [for i in range(0, storageAccountCount): {
  name: '${baseName}storage${i}'
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}]

// Optional: Create a blob service and container for each storage account
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = [for i in range(0, storageAccountCount): {
  name: 'default'
  parent: storageAccounts[i]
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}]

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = [for i in range(0, storageAccountCount): {
  name: 'data'
  parent: blobServices[i]
  properties: {
    publicAccess: 'None'
  }
}]

// OUTPUTS - Values that can be used by other modules
output storageAccountNames array = [for i in range(0, storageAccountCount): storageAccounts[i].name]
output primaryStorageAccountName string = storageAccounts[0].name
output primaryStorageAccountId string = storageAccounts[0].id
