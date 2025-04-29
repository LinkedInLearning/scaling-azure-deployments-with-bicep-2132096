// modules/database.bicep
// Provisions the database tier with Azure SQL Database

@description('Resource location')
param location string

@description('Resource tags')
param tags object = {}

@description('SQL Server name')
param sqlServerName string

@description('Database name')
param databaseName string

@description('SQL Server admin login')
@secure()
param adminLogin string

@description('SQL Server admin password')
@secure()
param adminPassword string

@description('SQL Database SKU')
param databaseSku object = {
  name: 'Standard'
  tier: 'Standard'
  capacity: 10
}

// Create SQL Server
resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    version: '12.0'
    publicNetworkAccess: 'Enabled'  // Consider 'Disabled' for production
  }
}

// Allow Azure services to connect to SQL Server
resource sqlFirewallRule 'Microsoft.Sql/servers/firewallRules@2021-11-01' = {
  parent: sqlServer
  name: 'AllowAllAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Create SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01' = {
  parent: sqlServer
  name: databaseName
  location: location
  tags: tags
  sku: databaseSku
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

// Output the connection string for dependent modules
output connectionString string = 'Server=tcp:${sqlServer.name}.database.windows.net,1433;Database=${sqlDatabase.name};User ID=${adminLogin};Password=${adminPassword};Encrypt=true;Connection Timeout=30;'
output sqlServerFqdn string = '${sqlServer.name}.database.windows.net'
output databaseName string = sqlDatabase.name
