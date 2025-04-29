// modules/security/keyvault.bicep - Security module for Key Vault deployment
@description('Azure region for deployment')
param location string

@description('Name of the Key Vault')
param keyVaultName string

@description('Enable RBAC authorization?')
param enableRbacAuthorization bool = true

@description('Subnet ID for private endpoint')
param subnetId string

@description('Log Analytics workspace ID for diagnostic settings')
param logAnalyticsWorkspaceId string

@description('Tags to apply to resources')
param tags object = {}

@description('Soft delete retention days')
param softDeleteRetentionInDays int = 90

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    enableRbacAuthorization: enableRbacAuthorization
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: true
    sku: {
      family: 'A'
      name: 'standard'
    }
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: [
        {
          id: subnetId
        }
      ]
    }
  }
}

// Private endpoint for secure access
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: '${keyVaultName}-pe'
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: '${keyVaultName}-pe-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

// Diagnostic settings for Key Vault
resource kvDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVaultName}-diagnostics'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
      {
        category: 'AzurePolicyEvaluationDetails'
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

// Azure Policy assignment to enforce TLS 1.2
resource tlsPolicy 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: '${keyVaultName}-enforce-tls12'
  scope: keyVault
  properties: {
    displayName: 'Enforce TLS 1.2 for Key Vault'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/ff4b2f65-06b6-46b2-a197-1c68b9bbcca9'
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
    enforcementMode: 'Default'
  }
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
