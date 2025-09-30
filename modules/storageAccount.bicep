targetScope = 'resourceGroup'

@minLength(3)
@maxLength(24)
@description('Name of the storage account to create. Must be between 3 and 24 characters in length and may contain numbers and lowercase letters only.')
param storageAccountName string
@description('Storage account SKU')
param storageAccountSku string
@description('Storage account kind')
param storageAccountKind string
@description('Indicates whether https traffic only should be enabled. Default is true.')
param storageAccountHttpsTrafficOnly bool
@description('File share to store application files')
param fileShareFolderName string = 'content-files'
@description('Additional properties for the file share, e.g., shareQuota. See https://learn.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts/fileservices/shares for details.')
param fileShareProperties object = {} // If empty, it will create an SMB file share with default properties

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('Log Analytics workspace to use for diagnostics settings')
param logAnalyticsWorkspaceName string

@description('Prefix to use when creating the resources in this deployment.')
param applicationName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: location
  kind: storageAccountKind
  sku: {
    name: storageAccountSku
  }
  properties: {
    supportsHttpsTrafficOnly: storageAccountHttpsTrafficOnly
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Disabled'
  }
}

// Configuring diagnostics settings for Storage Account
resource existingWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource storageAccountDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: storageAccount
  name: 'StorageAccountDiagnostics'
  properties: {
    workspaceId: existingWorkspace.id
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}
// End of configuring diagnostics settings for Storage Account

// Configuring file services and file share
resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2025-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource fileServicesDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: fileServices
  name: 'FileServicesDiagnostics'
  properties: {
    workspaceId: existingWorkspace.id
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2025-01-01' = {
  parent: fileServices
  name: fileShareFolderName
  properties: fileShareProperties
}
// End of configuring file services and file share

// Configuring private endpoint
@description('Virtual network for a private endpoint')
param vNetName string
@description('Target subnet to create a private endpoint')
param privateEndpointsSubnetName string
@description('File share private endpoint name')
param privateEndpointName string = '${applicationName}-pl-file-${uniqueString(resourceGroup().id)}'

var privateDnsZoneName = 'privatelink.file.${environment().suffixes.storage}'
var pvtEndpointDnsGroupName = '${privateEndpointName}/file'

resource existingVNet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vNetName
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  name: privateEndpointsSubnetName
  parent: existingVNet
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  properties: {}
}

resource privateDnsZoneName_privateDnsZoneName_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
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

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
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
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
}

resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
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

output fileShareFullName string = fileShare.name
