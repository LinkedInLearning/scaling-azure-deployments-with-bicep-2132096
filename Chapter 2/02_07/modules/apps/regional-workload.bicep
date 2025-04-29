// modules/apps/regional-workload.bicep - Multi-region application deployment module
targetScope = 'resourceGroup'

@description('Azure region for deployment')
param location string

@description('Environment name (dev, test, prod)')
param environment string

@description('Workload or application name')
param workload string

@description('App service SKU')
param appServiceSku object = {
  name: 'P1v2'
  tier: 'PremiumV2'
  size: 'P1v2'
  family: 'Pv2'
  capacity: 1
}

@description('Tags to apply to resources')
param tags object = {
  environment: environment
  workload: workload
  region: location
}

param logAnalyticsName string
param rgName string 
param vnetName string
param appServicePlanName string
param appServiceName string
param appServiceDiagnosticsName string

// Deploy regional logging
module logging '../core/logging.bicep' = {
  name: 'regional-logging-${location}'
  scope: az.resourceGroup(rgName)
  params: {
    location: location
    logAnalyticsName: logAnalyticsName
    tags: tags
  }
}

// Deploy regional networking
module network '../networking/vnet.bicep' = {
  name: 'regional-network-${location}'
  scope: az.resourceGroup(rgName)
  params: {
    location: location
    vnetName: vnetName
    subnets: [
      { name: 'web', cidr: '10.0.1.0/24' }
      { name: 'app', cidr: '10.0.2.0/24' }
    ]
    logAnalyticsWorkspaceId: logging.outputs.logAnalyticsWorkspaceId
    tags: tags
  }
  dependsOn: [
    logging
  ]
}

// App service plan
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: appServiceSku
  properties: {
    reserved: true // For Linux
  }
}

// App service
resource appService 'Microsoft.Web/sites@2022-09-01' = {
  name: appServiceName
  location: location
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      http20Enabled: true
      appSettings: [
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'REGION'
          value: location
        }
        {
          name: 'ENVIRONMENT'
          value: environment
        }
      ]
    }
  }
}

// App service diagnostic settings
resource appServiceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: appServiceDiagnosticsName
  scope: appService
  properties: {
    workspaceId: logging.outputs.logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
output appServiceName string = appService.name
output regionName string = location
