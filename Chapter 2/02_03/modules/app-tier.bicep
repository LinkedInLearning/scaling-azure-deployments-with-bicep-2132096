// modules/app-tier.bicep - App tier module for multi-tier application

// Parameters
param appName string
param location string = resourceGroup().location
param environment string
param sqlServerName string
param keyVaultName string
param sqlConnectionString string
param runtime string = 'dotnet'

// Variables
var functionAppName = '${appName}-func-${environment}'
var appServicePlanName = '${appName}-plan-${environment}'
var storageAccountName = toLower('${uniqueString(resourceGroup().id)}${environment}')
var vnetName = 'vnet-${environment}-app'
var subnetName = 'subnet-app'

// Virtual Network & Subnet for App Tier
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.2.0.0/16']
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.2.1.0/24'
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}

// Storage Account for Function App
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
  }
  kind: 'elastic'
  properties: {
    reserved: runtime == 'node' || runtime == 'python' ? true : false
  }
}

// Function App with VNet Integration
resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=core.windows.net;AccountKey=${listKeys(storageAccount.id, '2022-09-01').keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=core.windows.net;AccountKey=${listKeys(storageAccount.id, '2022-09-01').keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: runtime
        }
        {
          name: 'SQL_CONNECTION'
          value: sqlConnectionString
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1'
        }
      ]
      netFrameworkVersion: runtime == 'dotnet' ? 'v7.0' : null
      nodeVersion: runtime == 'node' ? '~18' : null
      pythonVersion: runtime == 'python' ? '3.9' : null
      javaVersion: runtime == 'java' ? '17' : null
    }
  }
}

// VNet integration for Function App
resource networkConfig 'Microsoft.Web/sites/networkConfig@2022-03-01' = {
  name: 'virtualNetwork'
  parent: functionApp
  properties: {
    subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, subnetName)
    swiftSupported: true
  }
}

// Private DNS Zone for App Tier to Data Tier communication
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.database.windows.net'
  location: 'global'
  properties: {}
}

// Link the private DNS zone to the VNet
resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${privateDnsZone.name}/${vnet.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Outputs
output functionAppName string = functionApp.name
output apiEndpoint string = 'https://${functionApp.properties.defaultHostName}/api'
output appServicePlanId string = appServicePlan.id
output storageAccountName string = storageAccount.name
output vnetId string = vnet.id
output subnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, subnetName)
