// main.bicep - Main deployment file that demonstrates key Bicep features
// This file shows modularity, dependency resolution, parameterization, and conditional logic

// PARAMETERS - Demonstrates parameterization and dynamic configuration
@description('Environment name. Used to create unique resource names and determine which resources to deploy')
@allowed([
  'dev'
  'test'
  'prod'
])
param environmentName string = 'dev'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Number of storage accounts to deploy')
param storageAccountCount int = 2

@description('Whether to deploy Azure Function')
param deployFunction bool = true

@description('App Service Plan SKU')
param appServicePlanSku object = {
  name: environmentName == 'prod' ? 'P1v2' : 'B1'
  tier: environmentName == 'prod' ? 'PremiumV2' : 'Basic'
}

// VARIABLES - Common naming convention and tags
var baseName = 'bicep${environmentName}'
var commonTags = {
  Environment: environmentName
  DeployedWith: 'Bicep'
  Project: 'LargeDeploymentDemo'
}

// MODULARITY - Using modules for different resource types
module storageModule 'modules/storage.bicep' = {
  name: 'storageDeployment'
  params: {
    location: location
    baseName: baseName
    tags: commonTags
    storageAccountCount: storageAccountCount
  }
}

module appServiceModule 'modules/appService.bicep' = {
  name: 'appServiceDeployment'
  params: {
    location: location
    baseName: baseName
    tags: commonTags
    appServicePlanSku: appServicePlanSku
  }
}

// CONDITIONAL DEPLOYMENT - Deploy function only if deployFunction is true
module functionModule 'modules/serverless.bicep' = if (deployFunction) {
  name: 'functionDeployment'
  params: {
    location: location
    baseName: baseName
    tags: commonTags
    // DEPENDENCY RESOLUTION - Automatically handles dependencies
    // The function needs a storage account, so we reference the output from the storage module
    storageAccountName: storageModule.outputs.primaryStorageAccountName
    appServicePlanId: appServiceModule.outputs.appServicePlanId
  }
}

// OUTPUTS - Expose important information from the deployment
output storageAccountNames array = storageModule.outputs.storageAccountNames
output appServiceName string = appServiceModule.outputs.appServiceName
output functionAppName string = deployFunction ? functionModule.outputs.functionAppName : 'Not deployed'
