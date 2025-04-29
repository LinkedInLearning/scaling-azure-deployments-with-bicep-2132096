// multi-region-deployment.bicep - Template for deploying to multiple regions
targetScope = 'subscription'

// Core parameters
@description('Primary Azure region for deployment')
param location string

@description('Environment name (dev, test, prod)')
param environment string

@description('Workload or application name')
param workload string

@description('Array of regions to deploy to')
param regions array = [
  'eastus'
  'westus'
]

@description('Tags to apply to all resources')
param tags object = {
  environment: environment
  deployedBy: 'BicepFramework'
}

// Use naming module to ensure consistent naming
module naming 'modules/common/naming.bicep' = {
  name: 'regional-naming-${location}'
  params: {
    environment: environment
    workload: '${workload}-${location}'
  }
}

// Deploy to each region in the array
module regionalDeploy 'modules/apps/regional-workload.bicep' = [for region in regions: {
  name: 'regionalDeploy-${region}'
  scope: resourceGroup('${workload}-${region}-rg')
  params: {
    location: region
    environment: environment
    workload: workload
    logAnalyticsName: naming.outputs.logAnalyticsName
    rgName: naming.outputs.resourceGroupName
    appServicePlanName: naming.outputs.appServicePlanName
    appServiceName: naming.outputs.appServiceName
    appServiceDiagnosticsName: naming.outputs.appServiceDiagnosticsName
    vnetName: naming.outputs.vnetName
    tags: union(tags, {
      region: region
      deployment: 'multi-region'
    })
  }
}]

// Outputs from multi-region deployment
output deployedRegions array = [for (region, i) in regions: {
  name: region
  appServiceUrl: regionalDeploy[i].outputs.appServiceUrl
  appServiceName: regionalDeploy[i].outputs.appServiceName
}]
