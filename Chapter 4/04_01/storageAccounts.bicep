// storageAccounts.bicep - Deploys a batch of storage accounts
targetScope = 'resourceGroup'

// Parameters
@description('Azure region to deploy resources')
param location string

@description('Starting index for this batch')
param batchStart int

@description('Number of storage accounts in this batch')
param batchSize int

@description('Base name for resources')
param baseName string

// Generate unique storage account names
var storageAccountNames = [for i in range(0, batchSize): '${take(replace(baseName, '-', ''), 5)}${uniqueString(resourceGroup().id, '${batchStart + i}')}']

// Deploy storage accounts in the current batch
resource storageAccounts 'Microsoft.Storage/storageAccounts@2023-01-01' = [for name in storageAccountNames: {
  name: name
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}]

// Output the names of the deployed storage accounts
output storageAccountNames array = [for (name, i) in storageAccountNames: storageAccounts[i].name]
