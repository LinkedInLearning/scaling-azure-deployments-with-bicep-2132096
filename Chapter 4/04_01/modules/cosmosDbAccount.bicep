// modules/cosmosDbAccount.bicep - Configures Cosmos DB with multi-region writes
targetScope = 'resourceGroup'

// Parameters
@description('Name for the Cosmos DB account')
param cosmosDbName string

@description('Primary deployment region')
param primaryRegion string

@description('All regions to deploy to')
param regions array

// Configure multi-region Cosmos DB account
resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-11-15' = {
  name: cosmosDbName
  location: primaryRegion
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [for (region, i) in regions: {
      locationName: region
      failoverPriority: i
      isZoneRedundant: true
    }]
    enableMultipleWriteLocations: true
    enableAutomaticFailover: true
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

// Create a database
resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-11-15' = {
  parent: cosmosDb
  name: 'globaldb'
  properties: {
    resource: {
      id: 'globaldb'
    }
  }
}

// Create a container
resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-11-15' = {
  parent: cosmosDatabase
  name: 'items'
  properties: {
    resource: {
      id: 'items'
      partitionKey: {
        paths: [
          '/partitionKey'
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
      }
    }
  }
}

// Outputs
output cosmosDbAccountName string = cosmosDb.name
output cosmosDbEndpoint string = cosmosDb.properties.documentEndpoint
