targetScope = 'resourceGroup'

@minLength(2)
@maxLength(32)
param containerAppEnvironmentName string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('Specifies whether the environment only has an internal load balancer')
param internal bool

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
@description('Target subnet name to integrate the environment')
param integrationSubnetName string
@description('Target subnet prefix to integrate the environment')
param integrationSubnetPrefix string

resource existingVNet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vNetName
}

resource integrationSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: integrationSubnetName
  parent: existingVNet
  properties: {
    addressPrefix: integrationSubnetPrefix
    delegations: [
      {
        name: 'containerAppEnvironmentDelegation'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
      }
    ]
  }
}

resource containerEnvironment 'Microsoft.App/managedEnvironments@2025-02-02-preview' = {
  name: containerAppEnvironmentName
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
      infrastructureSubnetId: integrationSubnet.id
    }
    zoneRedundant: true
    // https://learn.microsoft.com/en-us/azure/container-apps/environment-type-consumption-only
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}
