// modules/core/resource-group.bicep - Core module for resource group deployment
targetScope = 'subscription'

@description('Name of the resource group')
param name string

@description('Location for the resource group')
param location string

@description('Tags to apply to the resource group')
param tags object = {}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: name
  location: location
  tags: tags
}

output resourceGroupName string = resourceGroup.name
output resourceGroupId string = resourceGroup.id
