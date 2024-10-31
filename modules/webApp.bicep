targetScope = 'resourceGroup'

@minLength(2)
@maxLength(60)
param webAppName string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('App Service Plan id to host the app')
param appServicePlanId string

@description('Log Analytics workspace to use for diagnostics settings')
param logAnalyticsWorkspaceName string

@description('Ghost container full image name and tag')
param ghostContainerImage string

@description('Storage account name to store Ghost content files')
param storageAccountName string

@secure()
param storageAccountAccessKey string

@description('File share name on the storage account to store Ghost content files')
param fileShareName string

@description('Path to mount the file share in the container')
param containerMountPath string

var containerImageReference = 'DOCKER|${ghostContainerImage}'

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    clientAffinityEnabled: false
    serverFarmId: appServicePlanId
    httpsOnly: true
    enabled: true
    reserved: true
    siteConfig: {
      http20Enabled: true
      httpLoggingEnabled: true
      minTlsVersion: '1.3'
      ftpsState: 'Disabled'
      linuxFxVersion: containerImageReference
      alwaysOn: true
      use32BitWorkerProcess: false
      azureStorageAccounts: {
        ContentFilesVolume: {
          type: 'AzureFiles'
          accountName: storageAccountName
          shareName: fileShareName
          mountPath: containerMountPath
          accessKey: storageAccountAccessKey
        }
      }
    }
  }
}

// Configuring virtual network integration
@description('Virtual network for a private endpoint')
param vNetName string
@description('Target subnet to integrate web app')
param webAppIntegrationSubnetName string

resource vNet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vNetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  name: webAppIntegrationSubnetName
  parent: vNet
}

resource webApp_vNetIntegration 'Microsoft.Web/sites/networkConfig@2023-12-01' = {
  parent: webApp
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: subnet.id
  }
}
//End of configuring virtual network integration


resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource webAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: webApp
  name: 'WebAppDiagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
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

output name string = webApp.name
output hostName string = webApp.properties.hostNames[0]
output principalId string = webApp.identity.principalId
