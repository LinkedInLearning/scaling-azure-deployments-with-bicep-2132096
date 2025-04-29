// main.bicep - Root orchestration template for the modular deployment framework
targetScope = 'subscription'

// Core parameters
@description('Primary Azure region for resource deployment')
param location string

@description('Environment name (dev, test, prod)')
param environment string

@description('Workload or application name')
param workload string = 'shared'

@description('Tags to apply to all resources')
param tags object = {
  environment: environment
  deployedBy: 'BicepFramework'
}

var rgName = 'adorahack-${environment}-${workload}-rg'

// Import naming module to ensure consistent naming
module naming 'modules/common/naming.bicep' = {
  name: 'naming-module-deployment'
  params: {
    environment: environment
    workload: workload
  }
}

// 1. Deploy core infrastructure layer - resource groups, logging, identity
module coreResourceGroup 'modules/core/resource-group.bicep' = {
  name: 'core-rg-deployment'
  params: {
    name: naming.outputs.resourceGroupName
    location: location
    tags: tags
  }
}

module logging 'modules/core/logging.bicep' = {
  name: 'logging-deployment'
  scope: resourceGroup(rgName)
  params: {
    location: location
    logAnalyticsName: naming.outputs.logAnalyticsName
    tags: tags
  }
  dependsOn: [
    coreResourceGroup
  ]
}

// 2. Deploy networking layer after core resources
module network 'modules/networking/vnet.bicep' = {
  name: 'network-deployment'
  scope: resourceGroup(rgName)
  params: {
    location: location
    vnetName: naming.outputs.vnetName
    subnets: [
      { name: 'web', cidr: '10.0.1.0/24' }
      { name: 'app', cidr: '10.0.2.0/24' }
      { name: 'data', cidr: '10.0.3.0/24' }
    ]
    logAnalyticsWorkspaceId: logging.outputs.logAnalyticsWorkspaceId
    tags: tags
  }
  dependsOn: [
    logging
  ]
}

// 3. Deploy security layer after networking
module keyvault 'modules/security/keyvault.bicep' = {
  name: 'keyvault-deployment'
  scope: resourceGroup(rgName)
  params: {
    location: location
    keyVaultName: naming.outputs.keyVaultName
    logAnalyticsWorkspaceId: logging.outputs.logAnalyticsWorkspaceId
    subnetId: 'subnet-id'
    tags: tags
  }
  dependsOn: [
    network
  ]
}

// 4. Deploy application-specific resources
module storage 'modules/storage/storage-account.bicep' = {
  name: 'storage-deployment'
  scope: resourceGroup(rgName)
  params: {
    location: location
    storageAccountName: naming.outputs.storageAccountName
    logAnalyticsWorkspaceId: logging.outputs.logAnalyticsWorkspaceId
    tags: tags
  }
  dependsOn: [
    keyvault
  ]
}

// Outputs from deployment
output resourceGroupName string = coreResourceGroup.outputs.resourceGroupName
output vnetId string = network.outputs.vnetId
output logAnalyticsWorkspaceId string = logging.outputs.logAnalyticsWorkspaceId
output keyVaultUri string = keyvault.outputs.keyVaultUri
