targetScope = 'resourceGroup'

@description('Log Analytics workspace name')
@minLength(4)
@maxLength(64)
param logAnalyticsWorkspaceName string

@description('Log Analytics workspace pricing tier')
@allowed([
  'Free'
  'LACluster'
  'PerGB2018'
  'PerNode'
  'Premium'
  'Standalone'
  'Standard'
])
param logAnalyticsWorkspaceSku string

@description('Location to deploy the resources')
param location string = resourceGroup().location

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: logAnalyticsWorkspaceSku
    }
  }
}

output id string = logAnalyticsWorkspace.id
