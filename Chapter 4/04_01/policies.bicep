// policies.bicep - Deploys Azure policies for resource consistency
targetScope = 'subscription'

// Parameters
@description('Base name for policy resources')
param baseName string

@description('Allowed VM SKUs')
param allowedVmSkus array = [
  'Standard_D4s_v3'
  'Standard_D8s_v3'
  'Standard_D16s_v3'
]

@description('RBAC role definition ID for the policy remediation')
param rbacRoleId string = '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor role

// Define policy to enforce VM SKU consistency
resource enforceVmSku 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: '${baseName}-enforce-vm-sku'
  properties: {
    displayName: 'Enforce approved VM SKUs'
    description: 'This policy enforces VM SKU consistency across the environment'
    policyType: 'Custom'
    mode: 'All'
    metadata: {
      category: 'Compute'
      version: '1.0.0'
      source: 'Bicep template'
    }
    parameters: {
      allowedSkus: {
        type: 'Array'
        metadata: {
          displayName: 'Allowed VM SKUs'
          description: 'The list of allowed VM SKUs'
        }
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Compute/virtualMachines'
          }
          {
            not: {
              field: 'Microsoft.Compute/virtualMachines/sku.name'
              in: '[parameters(\'allowedSkus\')]'
            }
          }
        ]
      }
      then: {
        effect: 'modify'
        details: {
          roleDefinitionIds: [
            rbacRoleId
          ]
          operations: [
            {
              operation: 'addOrReplace'
              field: 'Microsoft.Compute/virtualMachines/sku.name'
              value: allowedVmSkus[0] // Default to first allowed SKU
            }
          ]
        }
      }
    }
  }
}

// Assign the policy at subscription level
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: '${baseName}-vm-sku-assignment'
  properties: {
    displayName: 'Enforce VM SKU standards'
    description: 'Enforces approved VM SKUs across all deployments'
    policyDefinitionId: enforceVmSku.id
    parameters: {
      allowedSkus: {
        value: allowedVmSkus
      }
    }
    enforcementMode: 'Default'
  }
}

// Output the policy assignment ID
output policyAssignmentId string = policyAssignment.id
output policyDefinitionId string = enforceVmSku.id
