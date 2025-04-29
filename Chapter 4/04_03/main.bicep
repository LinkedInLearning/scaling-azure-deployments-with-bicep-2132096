// main.bicep
// Main deployment orchestration template for multi-tier architecture

// Parameters
@description('Environment name (dev, test, prod)')
param environmentName string = 'dev'

@description('Primary location for all resources')
param location string = resourceGroup().location

@description('Secondary location for failover resources')
param secondaryLocation string = 'westus'

@description('Enable high availability with failover database')
param enableFailover bool = false

@description('Administrator login for SQL Server')
@secure()
param sqlAdminLogin string

@description('Administrator password for SQL Server')
@secure()
param sqlAdminPassword string

@description('Container registry and image information')
param containerRegistry string
param appContainerImage string
param appContainerTag string = 'latest'

@description('Web application name')
param webAppName string = '${environmentName}-webapp'

// Variables
var sqlServerName = '${environmentName}-sqlserver'
var databaseName = '${environmentName}-database'
var failoverSqlServerName = '${environmentName}-sqlserver-failover'
var appServicePlanName = '${environmentName}-app-plan'
var containerAppEnvName = '${environmentName}-container-env'
var containerAppName = '${environmentName}-api'
var tags = {
  environment: environmentName
  application: 'Multi-Tier-Demo'
  deploymentType: 'Bicep'
}

// Database tier deployment
module databaseTier 'modules/database.bicep' = {
  name: 'deployDatabaseTier'
  params: {
    location: location
    tags: tags
    sqlServerName: sqlServerName
    databaseName: databaseName
    adminLogin: sqlAdminLogin
    adminPassword: sqlAdminPassword
  }
}

// Optional failover database deployment
module failoverDatabaseTier 'modules/database.bicep' = if (enableFailover) {
  name: 'deployFailoverDatabaseTier'
  params: {
    location: secondaryLocation
    tags: tags
    sqlServerName: failoverSqlServerName
    databaseName: databaseName
    adminLogin: sqlAdminLogin
    adminPassword: sqlAdminPassword
  }
  dependsOn: [
    databaseTier
  ]
}

// Application (middleware) tier deployment
module applicationTier 'modules/application.bicep' = {
  name: 'deployApplicationTier'
  params: {
    location: location
    tags: tags
    containerAppEnvName: containerAppEnvName
    containerAppName: containerAppName
    containerRegistry: containerRegistry
    containerImage: appContainerImage
    containerTag: appContainerTag
    primaryDbConnectionString: databaseTier.outputs.connectionString
    failoverDbConnectionString: enableFailover ? failoverDatabaseTier.outputs.connectionString : ''
    enableFailover: enableFailover
  }
  dependsOn: enableFailover ? [
    databaseTier
    failoverDatabaseTier
  ] : [
    databaseTier
  ]
}

// Web tier deployment
module webTier 'modules/web.bicep' = {
  name: 'deployWebTier'
  params: {
    location: location
    tags: tags
    appServicePlanName: appServicePlanName
    webAppName: webAppName
    apiEndpoint: applicationTier.outputs.apiUrl
  }
  dependsOn: [
    applicationTier
  ]
}

// Outputs
output webAppUrl string = webTier.outputs.webAppUrl
output apiUrl string = applicationTier.outputs.apiUrl
output primaryDatabaseConnectionString string = databaseTier.outputs.connectionString
output failoverDatabaseConnectionString string = enableFailover ? failoverDatabaseTier.outputs.connectionString : ''
