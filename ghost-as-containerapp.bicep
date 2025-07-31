targetScope = 'resourceGroup'

@description('Prefix to use when creating the resources in this deployment.')
param applicationNamePrefix string = 'ghost'

@description('App Service Plan pricing tier')
param appServicePlanSku string = 'B1'

@description('Log Analytics workspace pricing tier')
param logAnalyticsWorkspaceSku string = 'PerGB2018'

@description('Storage account pricing tier')
param storageAccountSku string = 'Standard_LRS'

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('MySQL server SKU')
param mySQLServerSku string = 'Standard_B1ms'

@description('MySQL server password')
@secure()
param databasePassword string

@description('Ghost container full image name and tag')
param ghostContainerName string = 'andrewmatveychuk/ghost-ai:latest'

@description('Container registry where the image is hosted')
param containerRegistryUrl string = 'https://index.docker.io/v1'

@allowed([
  'Container app only'
  'Container app with Azure Front Door Premium'
])
param deploymentConfiguration string = 'Container app only'

@description('Virtual network address prefix to use')
param vNetAddressPrefix string = '10.0.0.0/22'
@description('Address prefix for private links subnet')
param privateEndpointsSubnetPrefix string = '10.0.3.240/28'
@description('Address prefix for integration subnet')
param integrationSubnetPrefix string = '10.0.0.0/23'

var vNetName = '${applicationNamePrefix}-vnet-${uniqueString(resourceGroup().id)}'
var privateEndpointsSubnetName = 'privateEndpointsSubnet'
var integrationSubnetName = 'integrationSubnet'
var delegatedServiceName = 'Microsoft.App/managedEnvironments'

var containerAppName = '${applicationNamePrefix}-capp-${uniqueString(resourceGroup().id)}'
var containerAppEnvironmentName = '${applicationNamePrefix}-cenv-${uniqueString(resourceGroup().id)}'
var logAnalyticsWorkspaceName = '${applicationNamePrefix}-la-${uniqueString(resourceGroup().id)}'
var applicationInsightsName = '${applicationNamePrefix}-ai-${uniqueString(resourceGroup().id)}'
var keyVaultName = '${applicationNamePrefix}-kv-${uniqueString(resourceGroup().id)}'
var storageAccountName = '${applicationNamePrefix}stor${uniqueString(resourceGroup().id)}'

var mySQLServerName = '${applicationNamePrefix}-mysql-${uniqueString(resourceGroup().id)}'
var databaseLogin = 'ghost'
var databaseName = 'ghost'

var ghostContentFileShareName = 'contentfiles'
var ghostContentFilesMountPath = '/var/lib/ghost/content_files'
var siteUrl = (deploymentConfiguration == 'Container app with Azure Front Door Premium')
  ? 'https://${frontDoor!.outputs.frontDoorEndpointHostName}'
  : 'https://${containerApp.outputs.hostName}'

//Web app with Azure Front Door
var frontDoorName = '${applicationNamePrefix}-afd-${uniqueString(resourceGroup().id)}'

module vNet './modules/virtualNetwork.bicep' = {
  name: 'vNetDeploy'
  params: {
    vNetName: vNetName
    vNetAddressPrefix: vNetAddressPrefix
    privateEndpointsSubnetName: privateEndpointsSubnetName
    privateEndpointsSubnetPrefix: privateEndpointsSubnetPrefix
    integrationSubnetName: integrationSubnetName
    integrationSubnetPrefix: integrationSubnetPrefix
    delegatedServiceName: delegatedServiceName
    location: location
  }
}

module logAnalyticsWorkspace './modules/logAnalyticsWorkspace.bicep' = {
  name: 'logAnalyticsWorkspaceDeploy'
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceSku: logAnalyticsWorkspaceSku
    location: location
  }
}

module storageAccount './modules/storageAccount.bicep' = {
  name: 'storageAccountDeploy'
  params: {
    storageAccountName: storageAccountName
    storageAccountSku: storageAccountSku
    fileShareFolderName: ghostContentFileShareName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    location: location
    vNetName: vNetName
    privateEndpointsSubnetName: privateEndpointsSubnetName
  }
  dependsOn: [
    vNet
    logAnalyticsWorkspace
  ]
}

module keyVault './modules/keyVault.bicep' = {
  name: 'keyVaultDeploy'
  params: {
    keyVaultName: keyVaultName
    keyVaultSecretName: 'databasePassword'
    keyVaultSecretValue: databasePassword
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    location: location
    vNetName: vNetName
    privateEndpointsSubnetName: privateEndpointsSubnetName
    webAppName: containerAppName
  }
  dependsOn: [
    // containerApp
    vNet
    logAnalyticsWorkspace
  ]
}

module containerApp './modules/containerApp.bicep' = {
  name: 'containerAppDeploy'
  params: {
    containerAppEnvironmentName: containerAppEnvironmentName
    containerAppName: containerAppName
    containerImage: ghostContainerName
  }
  dependsOn: [
    // containerAppEnvironment
    vNet
  ]
}

module webAppSettings './modules/webAppSettings.bicep' = {
  name: 'webAppSettingsDeploy'
  params: {
    webAppName: containerAppName
    containerRegistryUrl: containerRegistryUrl
    ghostContainerImage: ghostContainerName
    containerMountPath: ghostContentFilesMountPath
    mySQLServerName: mySQLServerName
    databaseName: databaseName
    databaseLogin: databaseLogin
    databasePasswordSecretUri: keyVault.outputs.secretUri
    siteUrl: siteUrl
    applicationInsightsName: applicationInsightsName
    fileShareName: storageAccount.outputs.fileShareFullName
    storageAccountName: storageAccountName
  }
  dependsOn: [
    containerApp
    frontDoor
    mySQLServer
  ]
}

module containerAppEnvironment './modules/containerAppEnvironment.bicep' = {
  name: 'containerAppEnvironmentDeploy'
  params: {
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    applicationInsightsName: applicationInsightsName
    containerAppName: containerAppName
    integrationSubnetName: integrationSubnetName
    vNetName: vNetName
  }
  dependsOn: [
    logAnalyticsWorkspace
    applicationInsights
    vNet
  ]
}

module applicationInsights './modules/applicationInsights.bicep' = {
  name: 'applicationInsightsDeploy'
  params: {
    applicationInsightsName: applicationInsightsName
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    webAppName: containerAppName
  }
  dependsOn: [
    containerApp
    logAnalyticsWorkspace
  ]
}

module mySQLServer './modules/mySQLServer.bicep' = {
  name: 'mySQLServerDeploy'
  params: {
    administratorLogin: databaseLogin
    administratorPassword: databasePassword
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    mySQLServerName: mySQLServerName
    mySQLServerSku: mySQLServerSku
    vNetName: vNetName
    privateEndpointsSubnetName: privateEndpointsSubnetName
  }
  dependsOn: [
    vNet
    logAnalyticsWorkspace
  ]
}

module frontDoor './modules/frontDoor.bicep' = if (deploymentConfiguration == 'Container app with Azure Front Door Premium') {
  name: 'FrontDoorDeploy'
  params: {
    frontDoorProfileName: frontDoorName
    applicationName: applicationNamePrefix
    webAppName: containerAppName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  }
  dependsOn: [
    containerApp
    logAnalyticsWorkspace
  ]
}

output webAppHostName string = containerApp.outputs.hostName
output endpointHostName string = siteUrl
