targetScope = 'resourceGroup'

@minLength(2)
@maxLength(32)
param containerAppEnvironmentName string

param containerAppEnvironmentStorageName string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('Specifies whether the environment only has an internal load balancer')
param internal bool

// Configuring logging
@description('Log Analytics workspace to use for diagnostics settings')
param logAnalyticsWorkspaceName string

@description('Application Insights to use by web app')
param applicationInsightsName string

@description('Storage account name to store Ghost content files')
param storageAccountName string

@description('File share name on the storage account to store Ghost content files')
param fileShareName string

resource existingWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource existingApplicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

// Configuring virtual network integration
@description('Virtual network to use for the Container App Environment')
param vNetName string
@description('Subnet name for the Container App Environment')
param subnetName string = 'cenv-subnet'
@description('Subnet prefix for the Container App Environment')
param subnetPrefix string

var delegatedServiceName = 'Microsoft.App/environments'

resource existingVNet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vNetName
}

resource containerEnvironmentSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: subnetName
  parent: existingVNet
  properties: {
    addressPrefix: subnetPrefix
    delegations: [
      {
        name: 'containerAppEnvironmentDelegation'
        properties: {
          serviceName: delegatedServiceName
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
      infrastructureSubnetId: containerEnvironmentSubnet.id
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

// Configuring storage for the Container App environment
resource existingStorageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: storageAccountName
}

resource environmentStorage 'Microsoft.App/managedEnvironments/storages@2025-02-02-preview' = {
  parent: containerEnvironment
  name: containerAppEnvironmentStorageName
  properties: {
    /* azureFile: {
      accessMode: 'ReadWrite'
      accountName: storageAccountName
      accountKey: existingStorageAccount.listKeys().keys[0].value
      shareName: fileShareName
    } */
    nfsAzureFile: {
      accessMode: 'ReadWrite'
      shareName: '/${existingStorageAccount.name}/${fileShareName}'
      server: parseUri(existingStorageAccount.properties.primaryEndpoints.file).host
    }
  }
}
