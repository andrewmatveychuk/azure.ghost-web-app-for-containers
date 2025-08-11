targetScope = 'resourceGroup'

@minLength(2)
@maxLength(60)
param webAppName string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('App Service Plan to host the app')
param appServicePlanName string

@description('Log Analytics workspace to use for diagnostics settings')
param logAnalyticsWorkspaceName string

resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' existing = {
  name: appServicePlanName
}

resource webApp 'Microsoft.Web/sites@2024-11-01' = {
  name: webAppName
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    clientAffinityEnabled: false
    serverFarmId: appServicePlan.id
    httpsOnly: true
    enabled: true
    reserved: true
  }
}

// Configuring virtual network integration
@description('Virtual network for a private endpoint')
param vNetName string
@description('Target subnet to integrate web app')
param webAppIntegrationSubnetName string

resource existingVNet 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  name: vNetName
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' existing = {
  name: webAppIntegrationSubnetName
  parent: existingVNet
}

resource webApp_VNetIntegration 'Microsoft.Web/sites/networkConfig@2024-11-01' = {
  parent: webApp
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: existingSubnet.id
  }
}
//End of configuring virtual network integration

// Configuring diagnostics settings for web app
resource existingWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource webAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: webApp
  name: 'WebAppDiagnostics'
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
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
      }
      {
        category: 'AppServiceIPSecAuditLogs'
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
      }
    ]
  }
}
// End of configuring diagnostics settings for web app

output hostName string = webApp.properties.hostNames[0]
output principalId string = webApp.identity.principalId
output principalName string = webApp.name
