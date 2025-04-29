// modules/appService.bicep - App Service module
// Demonstrates parameterization with flexible SKU options

@description('Location for all resources.')
param location string

@description('Base name for resources')
param baseName string

@description('Common tags for all resources')
param tags object

@description('App Service Plan SKU')
param appServicePlanSku object = {
  name: 'B1'
  tier: 'Basic'
}

// App Service Plan with dynamic SKU based on parameters
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${baseName}-plan'
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku.name
    tier: appServicePlanSku.tier
  }
  properties: {
    reserved: false // Set to true for Linux
  }
}

// App Service that depends on the App Service Plan
resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: '${baseName}-app'
  location: location
  tags: union(tags, {
    'Type': 'WebApp'
  })
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'ENVIRONMENT'
          value: tags.Environment
        }
      ]
    }
  }
}

// App Service Slot for production environments (conditional logic example)
resource stagingSlot 'Microsoft.Web/sites/slots@2022-03-01' = if (contains(tags, 'Environment') && tags.Environment == 'prod') {
  name: 'staging'
  parent: appService
  location: location
  tags: union(tags, {
    'Type': 'WebAppSlot'
  })
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'ENVIRONMENT'
          value: '${tags.Environment}-staging'
        }
      ]
    }
  }
}

// OUTPUTS
output appServicePlanId string = appServicePlan.id
output appServiceName string = appService.name
output appServiceHostName string = appService.properties.defaultHostName
