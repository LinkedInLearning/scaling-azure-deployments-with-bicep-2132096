// naming.bicep - Standardized resource naming convention
// Generate standardized resource names across the organization
targetScope = 'subscription'

@description('Environment name (dev, test, prod)')
param environment string

@description('Workload or application name')
param workload string

@description('Optional organizational prefix')
param orgPrefix string = 'adorahack'

// Create standardized resource prefix
var resourcePrefix = '${orgPrefix}-${environment}-${workload}'

// Output standardized resource names
output resourceGroupName string = '${resourcePrefix}-rg'
output storageAccountName string = replace('${resourcePrefix}st', '-', '')
output keyVaultName string = '${resourcePrefix}-kv'
output vnetName string = '${resourcePrefix}-vnet'
output appServiceName string = '${resourcePrefix}-app'
output appServicePlanName string = '${resourcePrefix}-plan'
output appServiceDiagnosticsName string = '${resourcePrefix}-diag'
output cosmosDbName string = '${resourcePrefix}-cosmos'
output acrName string = replace('${resourcePrefix}acr', '-', '')
output aksName string = '${resourcePrefix}-aks'
output logAnalyticsName string = '${resourcePrefix}-la'
