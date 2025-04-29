// main.bicep - Orchestration for large-scale deployments
targetScope = 'subscription'

// Parameters
@description('Number of storage accounts to deploy')
param storageAccountCount int = 500

@description('Batch size for deployments to avoid throttling')
param batchSize int = 20

@description('Deployment locations')
param deploymentRegions array = [
  'eastus'
  'westus'
]

@description('Base name for all resources')
param baseName string = 'largedepl'

// Variables
var uniqueDeploymentId = uniqueString(subscription().id, baseName)

// Create regional resource groups
resource resourceGroups 'Microsoft.Resources/resourceGroups@2023-07-01' = [for region in deploymentRegions: {
  name: '${baseName}-${region}-rg'
  location: region
}]

// Deploy batches of storage accounts across regions
module storageAccountBatches 'storageAccountBatch.bicep' = [for (region, i) in deploymentRegions: {
  name: 'storageDeployment-${region}-${uniqueDeploymentId}'
  scope: resourceGroups[i]
  params: {
    location: region
    storageAccountCount: storageAccountCount
    batchSize: batchSize
    baseName: baseName
  }
}]

// Deploy regional Cosmos DB instances
module cosmosDbDeployment 'cosmosDb.bicep' = {
  name: 'cosmosDeployment-${uniqueDeploymentId}'
  params: {
    regions: deploymentRegions
    baseName: baseName
  }
}

// Deploy policy for VM SKU consistency
module vmPolicyDeployment 'policies.bicep' = {
  name: 'policyDeployment-${uniqueDeploymentId}'
  scope: subscription()
  params: {
    baseName: baseName
  }
}

// Output the resource group names
output resourceGroupNames array = [for (region, i) in deploymentRegions: resourceGroups[i].name]
