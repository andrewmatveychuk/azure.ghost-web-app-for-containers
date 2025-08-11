targetScope = 'resourceGroup'

@description('Key Vault name')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Secret name to store')
@minLength(1)
@maxLength(127)
param keyVaultSecretName string

@description('Secret value to store')
@secure()
param keyVaultSecretValue string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('Log Analytics workspace to use for diagnostics settings')
param logAnalyticsWorkspaceName string

@description('Service principal name to provide access to Key Vault')
param principalName string

@description('Service principal ID to provide access to Key Vault')
param principalId string

resource keyVault 'Microsoft.KeyVault/vaults@2024-12-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'None'
    }
    enableRbacAuthorization: true
  }
}

// Key Vault RBAC roles mapping
var roleIdMapping = {
  'Key Vault Administrator': '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  'Key Vault Certificates Officer': 'a4417e6f-fecd-4de8-b567-7b0420556985'
  'Key Vault Crypto Officer': '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'
  'Key Vault Crypto Service Encryption User': 'e147488a-f6f5-4113-8e2d-b22465e65bf6'
  'Key Vault Crypto User': '12338af0-0e69-4776-bea7-57ae8d297424'
  'Key Vault Reader': '21090545-7ca7-4776-b22c-e363652d74d2'
  'Key Vault Secrets Officer': 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
  'Key Vault Secrets User': '4633458b-17de-408a-b874-0445c86b69e6'
}

resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(roleIdMapping['Key Vault Secrets User'], principalName, keyVault.name)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIdMapping['Key Vault Secrets User'])
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2024-12-01-preview' = {
  parent: keyVault
  name: keyVaultSecretName
  properties: {
    value: keyVaultSecretValue
  }
}

// Configuring diagnostics settings for Key Vault
resource existingWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: keyVault
  name: 'KeyVaultDiagnostics'
  properties: {
    workspaceId: existingWorkspace.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
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
  }
}
// End of configuring diagnostics settings for Key Vault

// Configuring private endpoint
@description('Virtual network for a private endpoint')
param vNetName string
@description('Target subnet to create a private endpoint')
param privateEndpointsSubnetName string

var privateEndpointName = 'ghost-pl-kv-${uniqueString(resourceGroup().id)}'
var privateDnsZoneName = 'privatelink.vaultcore.azure.net'
var pvtEndpointDnsGroupName = '${privateEndpointName}/keyvault'

resource existingVNet 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  name: vNetName
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' existing = {
  name: privateEndpointsSubnetName
  parent: existingVNet
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  properties: {}
}

resource privateDnsZoneName_privateDnsZoneName_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: '${existingVNet.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: existingVNet.id
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-07-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: existingSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-07-01' = {
  name: pvtEndpointDnsGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    privateEndpoint
  ]
}
// End of configuring private endpoint

output secretUri string = secret.properties.secretUri
