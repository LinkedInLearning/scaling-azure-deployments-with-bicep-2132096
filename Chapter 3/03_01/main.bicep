// main.bicep - Main template for multi-environment deployment (Dev, Test, Prod)

@description('Environment name: Dev, Test, or Prod')
@allowed([
  'Dev'
  'Test'
  'Prod'
])
param environment string

@description('Name of the App Service Plan')
param appServicePlanName string

@description('Name of the Web App')
param webAppName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags object = {
  Environment: environment
  DeployedBy: 'Bicep'
}

// SKU mapping based on environment
var skuInfo = {
  Dev: {
    name: 'B1'
    tier: 'Basic'
  }
  Test: {
    name: 'S1'
    tier: 'Standard'
  }
  Prod: {
    name: 'P1V2'
    tier: 'PremiumV2'
  }
}

// App insights and logging configuration based on environment
var appInsightsConfig = {
  Dev: {
    retentionInDays: 30
    samplingPercentage: 100
  }
  Test: {
    retentionInDays: 90
    samplingPercentage: 50
  }
  Prod: {
    retentionInDays: 365
    samplingPercentage: 25
  }
}

// Define App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: skuInfo[environment].name
    tier: skuInfo[environment].tier
  }
  properties: {
    reserved: false // Set to true for Linux
  }
}

// Define Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${webAppName}-appinsights'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: appInsightsConfig[environment].retentionInDays
    SamplingPercentage: appInsightsConfig[environment].samplingPercentage
  }
}

// Define Web App
resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: webAppName
  location: location
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'ENVIRONMENT'
          value: environment
        }
      ]
    }
  }
}

// Define environment-specific scaling rules for production
resource autoScaleSettings 'Microsoft.Insights/autoscalesettings@2022-10-01' = if (environment == 'Prod') {
  name: '${appServicePlanName}-autoscale'
  location: location
  tags: tags
  properties: {
    enabled: true
    targetResourceUri: appServicePlan.id
    profiles: [
      {
        name: 'Auto scale based on CPU'
        capacity: {
          minimum: '1'
          maximum: '5'
          default: '1'
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: appServicePlan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT10M'
            }
          }
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: appServicePlan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT10M'
            }
          }
        ]
      }
    ]
  }
}

// Define diagnostic settings based on environment
resource webAppDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${webAppName}-diagnostics'
  scope: webApp
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
        retentionPolicy: {
          days: environment == 'Prod' ? 365 : (environment == 'Test' ? 90 : 30)
          enabled: true
        }
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
        retentionPolicy: {
          days: environment == 'Prod' ? 365 : (environment == 'Test' ? 90 : 30)
          enabled: true
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: environment == 'Prod' ? 365 : (environment == 'Test' ? 90 : 30)
          enabled: true
        }
      }
    ]
  }
}

// Define Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${webAppName}-workspace'
  location: location
  tags: tags
  properties: {
    sku: {
      name: environment == 'Prod' ? 'PerGB2018' : 'PerGB2018'
    }
    retentionInDays: environment == 'Prod' ? 365 : (environment == 'Test' ? 90 : 30)
  }
}

// Outputs
output webAppHostName string = webApp.properties.defaultHostName
output webAppName string = webApp.name
output appServicePlanId string = appServicePlan.id
output environmentName string = environment
