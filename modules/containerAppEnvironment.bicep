targetScope = 'resourceGroup'

@minLength(2)
@maxLength(32)
param containerAppName string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('Specifies whether the environment only has an internal load balancer')
param internal bool = false

// Configuring logging
@description('Log Analytics workspace to use for diagnostics settings')
param logAnalyticsWorkspaceName string

@description('Application Insights to use by web app')
param applicationInsightsName string

resource existingWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource existingApplicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

// Configuring virtual network integration
@description('Virtual network for a private endpoint')
param vNetName string
@description('Target subnet to integrate web app')
param integrationSubnetName string

resource existingVNet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vNetName
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  name: integrationSubnetName
  parent: existingVNet
}

resource containerEnvironment 'Microsoft.App/managedEnvironments@2025-02-02-preview' = {
  name: '${containerAppName}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: existingWorkspace.properties.customerId
        sharedKey: existingWorkspace.listKeys().primarySharedKey
      }
    }
    appInsightsConfiguration: {
      connectionString: existingApplicationInsights.properties.ConnectionString
    }
    vnetConfiguration: {
      internal: internal
      infrastructureSubnetId: existingSubnet.id
    }
    zoneRedundant: true
  }
}
