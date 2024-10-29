targetScope = 'resourceGroup'

@description('Log Analytics workspace name')
@minLength(4)
@maxLength(63)
param logAnalyticsWorkspaceName string

@description('Log Analytics workspace pricing tier')
@allowed([
  'PerGB2018'
])
param logAnalyticsWorkspaceSku string

@description('Location to deploy the resources')
param location string = resourceGroup().location

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: logAnalyticsWorkspaceSku
    }
  }
}
