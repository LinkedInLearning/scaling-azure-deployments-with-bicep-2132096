// main.bicep - Parent template for multi-tier application

// Parameters
@description('Environment name (dev, test, staging, prod)')
param environment string = 'prod'

@description('Azure region for resource deployment')
param location string = resourceGroup().location

@description('Username for SQL Server administrator')
param sqlAdminUsername string = 'adminuser'

@description('Password for SQL Server administrator')
@secure()
param sqlAdminPassword string

@description('SKU for SQL Database')
param sqlSku string = 'GP_Gen5'

@description('Enable geo-replication for SQL Database')
param enableGeoReplication bool = false

@description('SKU for CDN')
param cdnSku string = 'Standard_Microsoft'

@description('Runtime for the App Service')
param runtime string = 'dotnet'

// Deploy Data Tier (SQL + Key Vault)
module dataTier 'modules/data-tier.bicep' = {
  name: 'deployDataTier'
  params: {
    environment: environment
    location: location
    sqlAdminUsername: sqlAdminUsername
    sqlAdminPassword: sqlAdminPassword
    sqlSku: sqlSku
    enableGeoReplication: enableGeoReplication
  }
}

// Deploy App Tier (Function App)
module appTier 'modules/app-tier.bicep' = {
  name: 'deployAppTier'
  params: {
    appName: 'eShopAPI'
    environment: environment
    location: location
    sqlServerName: dataTier.outputs.sqlServerName
    keyVaultName: dataTier.outputs.keyVaultName
    sqlConnectionString: dataTier.outputs.sqlConnectionString
    runtime: runtime
  }
  dependsOn: [
    dataTier
  ]
}

// Deploy Web Tier (Frontend)
module webTier 'modules/web-tier.bicep' = {
  name: 'deployWebTier'
  params: {
    appName: 'eShopFrontend'
    environment: environment
    location: location
    deploymentType: 'appService'
    cdnSku: cdnSku
  }
}

// Outputs
output webEndpoint string = webTier.outputs.webEndpoint
output apiEndpoint string = appTier.outputs.apiEndpoint
output sqlServerName string = dataTier.outputs.sqlServerName
