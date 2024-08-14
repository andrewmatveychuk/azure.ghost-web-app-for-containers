targetScope = 'resourceGroup'

@minLength(3)
@maxLength(63)
param mySQLServerName string

@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsWorkspaceId string

@description('Provide the location for all the resources.')
param location string = resourceGroup().location

@description('Provide the administrator login username for the flexible server.')
param administratorLogin string

@description('Provide the administrator login password for the flexible server.')
@secure()
param administratorPassword string

@description('Provide an array of firewall rules to apply to the flexible server.')
param firewallRules array = [
  {
    name: 'rule1'
    startIPAddress: '192.168.0.1'
    endIPAddress: '192.168.0.255'
  }
  {
    name: 'rule2'
    startIPAddress: '192.168.1.1'
    endIPAddress: '192.168.1.255'
  }
]

@description('The tier of the particular SKU. High availability mode is available only in the GeneralPurpose and MemoryOptimized SKUs.')
@allowed([
  'Burstable'
  'GeneralPurpose'
  'MemoryOptimized'
])
param serverEdition string = 'Burstable'

@description('Server version')
@allowed([
  '5.7'
  '8.0.21'
])
param version string = '8.0.21'

@description('The availability zone information for the server. If no preference, leave blank.')
param availabilityZone string = '1'

@description('High availability mode for a server: Disabled, SameZone, or ZoneRedundant.')
@allowed([
  'Disabled'
  'SameZone'
  'ZoneRedundant'
])
param haEnabled string = 'Disabled'

@description('The availability zone of the standby server.')
param standbyAvailabilityZone string = '2'

param storageSizeGB int = 20
param storageIops int = 360
@allowed([
  'Enabled'
  'Disabled'
])
param storageAutogrow string = 'Enabled'

@description('The name of the SKU, such as Standard_D32ds_v4.')
param mySQLServerSku string = 'Standard_B1ms'

param backupRetentionDays int = 7
@allowed([
  'Disabled'
  'Enabled'
])
param geoRedundantBackup string = 'Disabled'

resource mySQLServer 'Microsoft.DBforMySQL/flexibleServers@2021-12-01-preview' = {
  location: location
  name: mySQLServerName
  sku: {
    name: mySQLServerSku
    tier: serverEdition
  }
  properties: {
    version: version
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    availabilityZone: availabilityZone
    highAvailability: {
      mode: haEnabled
      standbyAvailabilityZone: standbyAvailabilityZone
    }
    storage: {
      storageSizeGB: storageSizeGB
      iops: storageIops
      autoGrow: storageAutogrow
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup
    }
  }
}

@batchSize(1)
module createFirewallRules './mySQLFirewallRules.bicep' = [for i in range(0, ((length(firewallRules) > 0) ? length(firewallRules) : 1)): {
  name: 'firewallRules-${i}'
  params: {
    ip: firewallRules[i]
    serverName: mySQLServerName
  }
  dependsOn: [
    mySQLServer
  ]
}]

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

output name string = mySQLServer.name
output fullyQualifiedDomainName string = mySQLServer.properties.fullyQualifiedDomainName

