// networking.bicep - A module for networking resources
// This demonstrates modularizing Bicep templates for better organization

@description('Environment name (dev, test, prod)')
param environmentName string

@description('Whether to enable public access to resources')
param enablePublicAccess bool

@description('Resource tags')
param tags object

@description('Location for all resources.')
param location string = resourceGroup().location

// Virtual Network
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-${environmentName}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}

// Network Security Group
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-${environmentName}'
  location: location
  tags: tags
  properties: {
    securityRules: enablePublicAccess ? [
      {
        name: 'AllowHTTP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'AllowHTTPS'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ] : [
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// Public IP - only deployed if enablePublicAccess is true
resource publicIp 'Microsoft.Network/publicIPAddresses@2021-05-01' = if (enablePublicAccess) {
  name: 'pip-${environmentName}'
  location: location
  tags: tags
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: 'app-${environmentName}-${uniqueString(resourceGroup().id)}'
    }
  }
}

// Bastion Host for secure access (in prod where public access is disabled)
resource bastion 'Microsoft.Network/bastionHosts@2021-05-01' = if (!enablePublicAccess) {
  name: 'bastion-${environmentName}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, 'AzureBastionSubnet')
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }
}

// Public IP for Bastion
resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2021-05-01' = if (!enablePublicAccess) {
  name: 'pip-bastion-${environmentName}'
  location: location
  tags: tags
  properties: {
    publicIPAllocationMethod: 'Static'
    sku: {
      name: 'Standard'
    }
  }
}

// Output the IDs of created resources
output virtualNetworkId string = virtualNetwork.id
output defaultSubnetId string = virtualNetwork.properties.subnets[0].id
output networkSecurityGroupId string = networkSecurityGroup.id
output publicIpId string = enablePublicAccess ? publicIp.id : ''
