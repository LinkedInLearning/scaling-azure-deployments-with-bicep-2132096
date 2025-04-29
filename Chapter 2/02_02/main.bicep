// main.bicep - Main deployment file showing how to use the web-app module

// Resource Group location
param location string = resourceGroup().location

// Project parameters
@description('Base name for your project resources')
param projectName string = 'adapp'

@description('Environment (dev, test, prod)')
@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'

@description('Function App runtime')
@allowed(['dotnet', 'node', 'python', 'java', 'powershell'])
param runtime string = 'node'

// Module reference - Deploy the web app module
module webApp 'web-app.bicep' = {
  name: 'webAppDeployment'
  params: {
    namePrefix: projectName
    environment: environment
    location: location
    planSku: 'Y1'          // Using serverless plan (Y1)
    osType: 'Linux'        // Using Linux as the OS
    storageSku: 'Standard_LRS'
    runtime: runtime
  }
}

// Outputs from the deployment
output functionAppName string = webApp.outputs.functionAppName
output functionAppUrl string = webApp.outputs.functionAppUrl
output storageAccountName string = webApp.outputs.storageAccountName
