// modules/networking/vnet.bicep - Networking module for virtual network deployment
@description('Azure region for deployment')
param location string

@description('Name of the virtual network')
param vnetName string

@description('Address space for the virtual network')
param addressSpace string = '10.0.0.0/16'

@description('Array of subnet configurations')
param subnets array = [
  { name: 'default', cidr: '10.0.0.0/24' }
]

@description('Log Analytics workspace ID for diagnostic settings')
param logAnalyticsWorkspaceId string

@description('Tags to apply to resources')
param tags object = {}

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-09-01' = [for subnet in subnets: {
  name: '${vnetName}-${subnet.name}-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      // Default security rules can be defined here
    ]
  }
}]

resource vnet 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpace
      ]
    }
    subnets: [for (subnet, i) in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.cidr
        networkSecurityGroup: {
          id: nsg[i].id
        }
        serviceEndpoints: [
          {
            service: 'Microsoft.KeyVault'
            locations: [
              '*'
            ]
          }
          {
            service: 'Microsoft.Storage'
            locations: [
              '*'
            ]
          }
        ]
      }
    }]
  }
}

// Diagnostic settings for virtual network
resource vnetDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${vnetName}-diagnostics'
  scope: vnet
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'VMProtectionAlerts'
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

// NSG diagnostic settings
resource nsgDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (subnet, i) in subnets: {
  name: '${vnetName}-${subnet.name}-nsg-diagnostics'
  scope: nsg[i]
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
}]

output vnetId string = vnet.id
output vnetName string = vnet.name
