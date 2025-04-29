// modules/application.bicep
// Provisions the middleware application tier using Azure Container Apps

@description('Resource location')
param location string

@description('Resource tags')
param tags object = {}

@description('Container App Environment name')
param containerAppEnvName string

@description('Container App name')
param containerAppName string

@description('Container registry where container image is stored')
param containerRegistry string

@description('Container image name')
param containerImage string

@description('Container image tag')
param containerTag string = 'latest'

@description('Primary database connection string')
@secure()
param primaryDbConnectionString string

@description('Failover database connection string (optional)')
@secure()
param failoverDbConnectionString string = ''

@description('Enable failover capability')
param enableFailover bool = false

@description('The number of CPU cores')
param cpuCores string = '0.5'

@description('The amount of memory')
param memorySize string = '1.0Gi'

@description('Minimum replicas')
param minReplicas int = 1

@description('Maximum replicas')
param maxReplicas int = 3

// Create Log Analytics workspace for container app monitoring
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${containerAppEnvName}-logs'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Create Container App Environment
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2022-10-01' = {
  name: containerAppEnvName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

// Create Container App
resource containerApp 'Microsoft.App/containerApps@2022-10-01' = {
  name: containerAppName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      secrets: [
        {
          name: 'primary-connection-string'
          value: primaryDbConnectionString
        }
        {
          name: 'failover-connection-string'
          value: failoverDbConnectionString
        }
      ]
    }
    template: {
      containers: [
        {
          name: containerAppName
          image: '${containerRegistry}/${containerImage}:${containerTag}'
          resources: {
            cpu: json(cpuCores)
            memory: memorySize
          }
          env: [
            {
              name: 'PRIMARY_DB_CONNECTION_STRING'
              secretRef: 'primary-connection-string'
            }
            {
              name: 'ENABLE_FAILOVER'
              value: string(enableFailover)
            }
            {
              name: 'FAILOVER_DB_CONNECTION_STRING'
              secretRef: 'failover-connection-string'
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scaling-rule'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
}

// Outputs
output apiUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output containerAppId string = containerApp.id
