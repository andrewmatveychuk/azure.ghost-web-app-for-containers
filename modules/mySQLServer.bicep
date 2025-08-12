targetScope = 'resourceGroup'

@minLength(3)
@maxLength(63)
param mySQLServerName string

@allowed([
  'Standard_B1ms'
  'Standard_B2ms'
])
param mySQLServerSku string

@description('Database administrator login name')
@minLength(1)
param administratorLogin string

@description('Database administrator password')
@secure()
param administratorPassword string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('Log Analytics workspace to use for diagnostics settings')
param logAnalyticsWorkspaceName string

@description('Prefix to use when creating the resources in this deployment.')
param applicationName string

resource mySQLServer 'Microsoft.DBforMySQL/flexibleServers@2024-12-01-preview' = {
  name: mySQLServerName
  location: location
  sku: {
    name: mySQLServerSku
    tier: 'Burstable'
  }
  properties: {
    createMode: 'Default'
    version: '8.0.21'
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    network: {
      publicNetworkAccess: 'Disabled'
    }
  }
}

output fullyQualifiedDomainName string = mySQLServer.properties.fullyQualifiedDomainName

// Configuring diagnostics settings for MySQL Server
resource existingWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource mySQLServerDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: mySQLServer
  name: 'MySQLServerDiagnostics'
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
        category: 'MySqlSlowLogs'
        enabled: true
      }
      {
        category: 'MySqlAuditLogs'
        enabled: true
      }
    ]
  }
}
// End of configuring diagnostics settings for MySQL Server

// Configuring private endpoint
@description('Virtual network for a private endpoint')
param vNetName string
@description('Target subnet to create a private endpoint')
param privateEndpointsSubnetName string

var privateEndpointName = '${applicationName}-pe-mysql-${uniqueString(resourceGroup().id)}'
var privateDnsZoneName = 'privatelink.mysql.database.azure.com'
var pvtEndpointDnsGroupName = '${privateEndpointName}/mysql'

resource existingVNet 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  name: vNetName
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' existing = {
  name: privateEndpointsSubnetName
  parent: existingVNet
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
          privateLinkServiceId: mySQLServer.id
          groupIds: [
            'mysqlServer'
          ]
        }
      }
    ]
  }
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
