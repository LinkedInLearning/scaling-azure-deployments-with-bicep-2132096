// Azure Global Deployment Bicep Template
// This template provisions resources for multi-region deployment with global routing

// Parameters
param location1 string = 'eastus'
param location2 string = 'westeurope'
param appServicePlanSku object = {
  name: 'S1'
  tier: 'Standard'
  capacity: 1
}
param applicationName string = 'globalapp'
param cosmosDbName string = '${applicationName}-cosmosdb'

// Variables
var trafficManagerName = '${applicationName}-tm'
var frontDoorName = '${applicationName}-fd'
var app1Name = '${applicationName}-${location1}'
var app2Name = '${applicationName}-${location2}'

// App Service Plans in each region
resource appServicePlan1 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${applicationName}-plan-${location1}'
  location: location1
  sku: appServicePlanSku
  properties: {
    reserved: false
  }
}

resource appServicePlan2 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${applicationName}-plan-${location2}'
  location: location2
  sku: appServicePlanSku
  properties: {
    reserved: false
  }
}

// Web Apps in each region
resource webApp1 'Microsoft.Web/sites@2022-03-01' = {
  name: app1Name
  location: location1
  properties: {
    serverFarmId: appServicePlan1.id
    httpsOnly: true
    siteConfig: {
      alwaysOn: true
      healthCheckPath: '/health'
    }
  }
}

resource webApp2 'Microsoft.Web/sites@2022-03-01' = {
  name: app2Name
  location: location2
  properties: {
    serverFarmId: appServicePlan2.id
    httpsOnly: true
    siteConfig: {
      alwaysOn: true
      healthCheckPath: '/health'
    }
  }
}

// Traffic Manager for global routing based on performance
resource trafficManager 'Microsoft.Network/trafficManagerProfiles@2022-04-01' = {
  name: trafficManagerName
  location: 'global'
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Performance'
    dnsConfig: {
      relativeName: applicationName
      ttl: 30
    }
    monitorConfig: {
      protocol: 'HTTPS'
      port: 443
      path: '/health'
      intervalInSeconds: 30
      timeoutInSeconds: 10
      toleratedNumberOfFailures: 3
    }
  }
}

// Traffic Manager Endpoints
resource eastUSEndpoint 'Microsoft.Network/trafficManagerProfiles/azureEndpoints@2022-04-01' = {
  parent: trafficManager
  name: 'eastus-endpoint'
  properties: {
    targetResourceId: webApp1.id
    endpointStatus: 'Enabled'
    weight: 1
    priority: 1
  }
}

resource westEuropeEndpoint 'Microsoft.Network/trafficManagerProfiles/azureEndpoints@2022-04-01' = {
  parent: trafficManager
  name: 'westeurope-endpoint'
  properties: {
    targetResourceId: webApp2.id
    endpointStatus: 'Enabled'
    weight: 1
    priority: 2
  }
}

// Front Door for edge-based global routing with advanced features
resource frontDoor 'Microsoft.Network/frontDoors@2021-06-01' = {
  name: frontDoorName
  location: 'global'
  properties: {
    friendlyName: frontDoorName
    enabledState: 'Enabled'
    
    frontendEndpoints: [
      {
        name: 'frontendEndpoint'
        properties: {
          hostName: '${frontDoorName}.azurefd.net'
          sessionAffinityEnabledState: 'Disabled'
        }
      }
    ]
    
    backendPools: [
      {
        name: 'backendPool'
        properties: {
          backends: [
            {
              address: webApp1.properties.defaultHostName
              backendHostHeader: webApp1.properties.defaultHostName
              httpPort: 80
              httpsPort: 443
              weight: 50
              priority: 1
              enabledState: 'Enabled'
            }
            {
              address: webApp2.properties.defaultHostName
              backendHostHeader: webApp2.properties.defaultHostName
              httpPort: 80
              httpsPort: 443
              weight: 50
              priority: 1
              enabledState: 'Enabled'
            }
          ]
          loadBalancingSettings: {
            sampleSize: 4
            successfulSamplesRequired: 3
          }
          healthProbeSettings: {
            probePath: '/health'
            probeRequestType: 'HEAD'
            probeProtocol: 'Https'
            probeIntervalInSeconds: 30
          }
        }
      }
    ]
    
    loadBalancingSettings: [
      {
        name: 'loadBalancingSettings'
        properties: {
          sampleSize: 4
          successfulSamplesRequired: 3
        }
      }
    ]
    
    healthProbeSettings: [
      {
        name: 'healthProbeSettings'
        properties: {
          path: '/health'
          protocol: 'Https'
          intervalInSeconds: 30
        }
      }
    ]
    
    routingRules: [
      {
        name: 'routingRule'
        properties: {
          frontendEndpoints: [
            {
              id: resourceId('Microsoft.Network/frontDoors/frontendEndpoints', frontDoorName, 'frontendEndpoint')
            }
          ]
          acceptedProtocols: [
            'Http'
            'Https'
          ]
          patternsToMatch: [
            '/*'
          ]
          routeConfiguration: {
            '@odata.type': '#Microsoft.Azure.FrontDoor.Models.FrontdoorForwardingConfiguration'
            forwardingProtocol: 'HttpsOnly'
            backendPool: {
              id: resourceId('Microsoft.Network/frontDoors/backendPools', frontDoorName, 'backendPool')
            }
          }
          enabledState: 'Enabled'
        }
      }
    ]
  }
}

// Cosmos DB with geo-replication within European regions for compliance
resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2022-08-15' = {
  name: cosmosDbName
  location: location2 // Primary location in West Europe
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    locations: [
      {
        locationName: 'West Europe'
        failoverPriority: 0
        isZoneRedundant: true
      }
      {
        locationName: 'North Europe'
        failoverPriority: 1
        isZoneRedundant: true
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: true
    enableMultipleWriteLocations: true
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

// Outputs
output trafficManagerFqdn string = trafficManager.properties.dnsConfig.fqdn
output frontDoorFqdn string = frontDoor.properties.frontendEndpoints[0].properties.hostName
output webapp1Url string = 'https://${webApp1.properties.defaultHostName}'
output webapp2Url string = 'https://${webApp2.properties.defaultHostName}'
output cosmosDbEndpoint string = cosmosDb.properties.documentEndpoint
