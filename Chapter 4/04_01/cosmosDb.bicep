// cosmosDb.bicep - Deploys globally distributed Cosmos DB
targetScope = 'subscription'

// Parameters
@description('Regions to deploy Cosmos DB')
param regions array

@description('Base name for resources')
param baseName string

// Variables
var cosmosName = '${baseName}-cosmos-${uniqueString(subscription().id, baseName)}'
var primaryRegion = regions[0]

// Create resource group for global resources
resource globalResourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${baseName}-global-rg'
  location: primaryRegion
}

// Deploy globally distributed Cosmos DB account
module cosmosDbAccount 'modules/cosmosDbAccount.bicep' = {
  name: 'cosmosDb-deployment'
  scope: globalResourceGroup
  params: {
    cosmosDbName: cosmosName
    primaryRegion: primaryRegion
    regions: regions
  }
}

// Output Cosmos DB account name
output cosmosDbAccountName string = cosmosDbAccount.outputs.cosmosDbAccountName
output cosmosDbEndpoint string = cosmosDbAccount.outputs.cosmosDbEndpoint
