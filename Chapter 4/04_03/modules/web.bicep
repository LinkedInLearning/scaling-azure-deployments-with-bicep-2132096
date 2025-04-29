// modules/web.bicep
// Provisions the web tier using Azure App Service

@description('Resource location')
param location string

@description('Resource tags')
param tags object = {}

@description('App Service Plan name')
param appServicePlanName string

@description('Web App name')
param webAppName string

@description('API endpoint URL from the application tier')
param apiEndpoint string

@description('App Service Plan SKU')
param sku object = {
  name: 'S1'
  tier: 'Standard'
  capacity: 1
}

// Create App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: sku.name
    tier: sku.tier
    capacity: sku.capacity
  }
  properties: {
    reserved: false // false for Windows, true for Linux
  }
}

// Create Web App
resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: webAppName
  location: location
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'API_ENDPOINT'
          value: apiEndpoint
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      netFrameworkVersion: 'v6.0'
    }
  }
}

// Deploy application insights for monitoring
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${webAppName}-insights'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    RetentionInDays: 90
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Link Application Insights to Web App
resource webAppAppInsights 'Microsoft.Web/sites/siteextensions@2022-03-01' = {
  parent: webApp
  name: 'Microsoft.ApplicationInsights.AzureWebSites'
  dependsOn: [
    appInsights
  ]
}

// Update Web App settings with Application Insights instrumentation key
resource webAppSettings 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: webApp
  name: 'appsettings'
  properties: {
    APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.properties.InstrumentationKey
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
    XDT_MicrosoftApplicationInsights_Mode: 'recommended'
    API_ENDPOINT: apiEndpoint
    WEBSITE_RUN_FROM_PACKAGE: '1'
  }
  dependsOn: [
    webAppAppInsights
  ]
}

// Outputs
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output webAppId string = webApp.id
