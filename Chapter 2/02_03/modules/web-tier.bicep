// modules/web-tier.bicep - Web tier module for multi-tier application

// Parameters
param appName string
param location string = resourceGroup().location
param environment string

@allowed([
  'appService'
  'staticWebsite'
])
param deploymentType string = 'appService'

param cdnSku string = 'Standard_Microsoft'

// Variables
var webAppName = '${appName}-${environment}'
var appServicePlanName = '${appName}-plan-${environment}'
var storageAccountName = toLower('${uniqueString(resourceGroup().id)}web${environment}')
var cdnProfileName = '${appName}-cdn-${environment}'
var cdnEndpointName = '${appName}-endpoint-${environment}'

// App Service resources for hosting a React app
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = if (deploymentType == 'appService') {
  name: appServicePlanName
  location: location
  sku: {
    name: 'S1'
    tier: 'Standard'
  }
  kind: 'app'
}

resource webApp 'Microsoft.Web/sites@2022-03-01' = if (deploymentType == 'appService') {
  name: webAppName
  location: location
  kind: 'app'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      http20Enabled: true
      appSettings: [
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
      ]
    }
  }
}

// Storage Account with Static Website enabled for hosting static files
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = if (deploymentType == 'staticWebsite') {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

// Enable static website hosting
resource staticWebsite 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = if (deploymentType == 'staticWebsite') {
  name: 'default'
  parent: storageAccount
  properties: {
    cors: {
      corsRules: [
        {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'HEAD', 'OPTIONS']
          allowedHeaders: ['*']
          exposedHeaders: ['*']
          maxAgeInSeconds: 3600
        }
      ]
    }
    deleteRetentionPolicy: {
      enabled: false
    }
  }
}

// Configure static website
resource staticWebsiteConfig 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = if (deploymentType == 'staticWebsite') {
  name: '$web'
  parent: staticWebsite
  properties: {
    publicAccess: 'None'
  }
}

// CDN Profile
resource cdnProfile 'Microsoft.Cdn/profiles@2022-11-01-preview' = {
  name: cdnProfileName
  location: 'global'
  sku: {
    name: cdnSku
  }
}

// CDN Endpoint for App Service
resource cdnEndpointAppService 'Microsoft.Cdn/profiles/endpoints@2022-11-01-preview' = if (deploymentType == 'appService') {
  name: cdnEndpointName
  parent: cdnProfile
  location: 'global'
  properties: {
    originHostHeader: webApp.properties.defaultHostName
    isHttpAllowed: false
    isHttpsAllowed: true
    queryStringCachingBehavior: 'UseQueryString'
    contentTypesToCompress: [
      'application/javascript'
      'application/json'
      'application/xml'
      'text/css'
      'text/html'
      'text/javascript'
      'text/plain'
    ]
    isCompressionEnabled: true
    origins: [
      {
        name: 'appServiceOrigin'
        properties: {
          hostName: webApp.properties.defaultHostName
          originHostHeader: webApp.properties.defaultHostName
          httpsPort: 443
          enabled: true
        }
      }
    ]
  }
}

// CDN Endpoint for Static Website
resource cdnEndpointStaticWebsite 'Microsoft.Cdn/profiles/endpoints@2022-11-01-preview' = if (deploymentType == 'staticWebsite') {
  name: cdnEndpointName
  parent: cdnProfile
  location: 'global'
  properties: {
    originHostHeader: '${storageAccount.name}.blob.core.windows.net'
    isHttpAllowed: false
    isHttpsAllowed: true
    queryStringCachingBehavior: 'UseQueryString'
    contentTypesToCompress: [
      'application/javascript'
      'application/json'
      'application/xml'
      'text/css'
      'text/html'
      'text/javascript'
      'text/plain'
    ]
    isCompressionEnabled: true
    origins: [
      {
        name: 'storageOrigin'
        properties: {
          hostName: '${storageAccount.name}.blob.core.windows.net'
          originHostHeader: '${storageAccount.name}.blob.core.windows.net'
          httpsPort: 443
          enabled: true
        }
      }
    ]
  }
}

// Outputs
output webEndpoint string = deploymentType == 'appService' 
  ? 'https://${cdnEndpointAppService.properties.hostName}'
  : 'https://${storageAccount.name}.blob.core.windows.net/$web'
output appServiceName string = deploymentType == 'appService' ? webApp.name : ''
output storageAccountName string = deploymentType == 'staticWebsite' ? storageAccount.name : ''
output cdnProfileName string = cdnProfile.name
output cdnEndpointName string = deploymentType == 'appService' 
  ? cdnEndpointAppService.name 
  : deploymentType == 'staticWebsite' 
    ? cdnEndpointStaticWebsite.name 
    : ''
