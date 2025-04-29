// web-app.bicep - Reusable module for Azure Function App deployment

// Global Settings  
@description('Base name for all resources (e.g., "adora")')
param namePrefix string

@description('Environment tag (e.g., "dev", "test", "prod")')
param environment string

@description('Azure region for resources')  
param location string = resourceGroup().location  

// App Service Plan  
@description('SKU tier for the App Service Plan (e.g., Y1 for serverless)')  
param planSku string = 'Y1'  

@description('Operating system type')  
@allowed(['Windows', 'Linux'])  
param osType string = 'Windows'  

// Storage Account  
@description('Performance tier for Storage Account')  
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_ZRS', 'Premium_LRS'])
param storageSku string = 'Standard_LRS'  

// Function App  
@description('Runtime stack for the Function App')  
@allowed(['dotnet', 'node', 'python', 'java', 'powershell'])  
param runtime string

// Tags for all resources
var tags = {
  environment: environment
  application: namePrefix
  deployedBy: 'Bicep'
}

// Create App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {  
  name: 'plan-${namePrefix}-${environment}'  
  location: location
  tags: tags
  sku: {  
    name: planSku  
    tier: planSku == 'Y1' ? 'Dynamic' : (startsWith(planSku, 'EP') ? 'ElasticPremium' : 'Standard')
  }  
  kind: osType == 'Linux' ? 'linux' : 'windows'
  properties: {
    reserved: osType == 'Linux' ? true : false
  }
}  

// Create Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {  
  name: 'st${toLower(replace(namePrefix, '-', ''))}${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  sku: {  
    name: storageSku  
  }  
  kind: 'StorageV2'  
  properties: {  
    supportsHttpsTrafficOnly: true  
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    accessTier: 'Hot'
  }  
}

// Get Storage Account Connection String
var storageAccountConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=core.windows.net;AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'

// Create Function App
resource functionApp 'Microsoft.Web/sites@2022-03-01' = {  
  name: 'func-${namePrefix}-${environment}'  
  location: location
  tags: tags
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {  
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {  
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [  
        {  
          name: 'AzureWebJobsStorage'  
          value: storageAccountConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageAccountConnectionString
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(namePrefix)
        }
        {  
          name: 'FUNCTIONS_WORKER_RUNTIME'  
          value: runtime  
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
      ]
    }  
  }
  dependsOn: [  
    storageAccount
    appServicePlan  
  ]  
}

// Outputs
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output storageAccountName string = storageAccount.name
