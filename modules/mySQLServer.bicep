targetScope = 'resourceGroup'

@minLength(3)
@maxLength(63)
param mySQLServerName string

@allowed([
  'Standard_B1s'
  'Standard_B1ms'
  'Standard_B2s'
])
param mySQLServerSku string

@description('Database administrator login name')
@minLength(1)
param administratorLogin string

@description('Database administrator password')
@minLength(8)
@maxLength(128)
@secure()
param administratorPassword string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsWorkspaceId string

resource mySQLServer 'Microsoft.DBforMySQL/flexibleServers@2021-05-01-preview' = {
  name: mySQLServerName
  location: location
  sku: {
    name: mySQLServerSku
    tier: 'Burstable'
  }
  properties: {
    version: '5.7'
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
  }
}

resource firewallRules 'Microsoft.DBforMySQL/flexibleServers/firewallRules@2021-05-01-preview' = {
  parent: mySQLServer
  name: 'AllowAzureIPs'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource mySQLServerDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: mySQLServer
  name: 'MySQLServerDiagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
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

output fullyQualifiedDomainName string = mySQLServer.properties.fullyQualifiedDomainName
