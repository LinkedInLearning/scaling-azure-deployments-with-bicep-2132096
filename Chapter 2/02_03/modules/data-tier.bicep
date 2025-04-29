// modules/data-tier.bicep - Data tier module for multi-tier application

// Parameters
param location string = resourceGroup().location
param environment string
param sqlAdminUsername string

@secure()
param sqlAdminPassword string
param sqlSku string = 'GP_Gen5'
param enableGeoReplication bool = false

// Variables
var sqlServerName = 'sql-${environment}'
var sqlDatabaseName = 'sqldb-${environment}'
var keyVaultName = 'kv-${toLower(uniqueString(resourceGroup().id))}-${environment}'
var vnetName = 'vnet-${environment}-data'
var subnetName = 'subnet-private-endpoint'
var privateEndpointName = 'pe-sql-${environment}'

// Virtual Network & Subnet for Private Endpoint
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.1.0.0/16']
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.1.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// Azure SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
    publicNetworkAccess: 'Disabled'
  }
}

// Azure SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  name: sqlDatabaseName
  parent: sqlServer
  location: location
  sku: {
    name: sqlSku
    tier: contains(sqlSku, 'GP') ? 'GeneralPurpose' : contains(sqlSku, 'BC') ? 'BusinessCritical' : 'Standard'
  }
  properties: {
    zoneRedundant: enableGeoReplication
  }
}

// Private Endpoint for SQL Server
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/${subnetName}'
    }
    privateLinkServiceConnections: [
      {
        name: 'pls-sql'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: ['sqlServer']
        }
      }
    ]
  }
}

// Key Vault to Store SQL Password
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    enableRbacAuthorization: true
  }
}

// SQL Connection String Secret
resource sqlConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'sqlConnectionString'
  parent: keyVault
  properties: {
    value: 'Server=tcp:${sqlServer.name}.database.windows.net,1433;Database=${sqlDatabase.name};User ID=${sqlAdminUsername};Password=${sqlAdminPassword};Encrypt=true;Connection Timeout=30;'
  }
}

// SQL Admin Password Secret
resource sqlPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'sqlAdminPassword'
  parent: keyVault
  properties: {
    value: sqlAdminPassword
  }
}

// Outputs
output sqlServerName string = sqlServer.name
output sqlDatabaseName string = sqlDatabase.name
output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id
output sqlConnectionString string = '@Microsoft.KeyVault(SecretUri=https://${keyVault.name}.vault.azure.net/secrets/sqlConnectionString/)'
output vnetId string = vnet.id
output subnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, subnetName)
