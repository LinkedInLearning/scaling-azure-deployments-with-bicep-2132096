// storageAccountBatch.bicep - Handles batched deployment of storage accounts
targetScope = 'resourceGroup'

// Parameters
@description('Azure region to deploy resources')
param location string

@description('Total number of storage accounts to deploy')
param storageAccountCount int

@description('Number of storage accounts per batch')
param batchSize int

@description('Base name for resources')
param baseName string

// Variables
var totalBatches = 2
var batchSizes = [for i in range(0, totalBatches): (i < totalBatches - 1 || storageAccountCount % batchSize == 0) ? batchSize : storageAccountCount % batchSize]

// Deploy storage accounts in batches
module storageBatches 'storageAccounts.bicep' = [for (size, i) in batchSizes: {
  name: 'storageBatch-${i}'
  params: {
    location: location
    batchStart: i * batchSize
    batchSize: size
    baseName: baseName
  }
}]

// Output the total number of storage accounts deployed
output totalStorageAccounts int = storageAccountCount
