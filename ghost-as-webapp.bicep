targetScope = 'resourceGroup'

@description('Prefix to use when creating the resources in this deployment.')
param applicationName string = 'ghost'

@description('App Service Plan pricing tier')
param appServicePlanSku string = 'B1'

@description('Log Analytics workspace pricing tier')
param logAnalyticsWorkspaceSku string = 'PerGB2018'

@description('Storage account pricing tier')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
])
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
  'Web app with public access'
  'Web app with Azure Front Door'
])
param deploymentConfiguration string = 'Web app with public access'

@description('Virtual network address prefix to use')
param vNetAddressPrefix string = '10.0.0.0/26'
@description('Address prefix for web app integration subnet')
param webAppIntegrationSubnetPrefix string = '10.0.0.0/28'
@description('Address prefix for private links subnet')
param privateEndpointsSubnetPrefix string = '10.0.0.16/28'

var vNetName = '${applicationName}-vnet-${uniqueString(resourceGroup().id)}'
var privateEndpointsSubnetName = 'pe-subnet'
var webAppIntegrationSubnetName = 'asp-integration-subnet'
var webAppName = '${applicationName}-web-${uniqueString(resourceGroup().id)}'
var appServicePlanName = '${applicationName}-asp-${uniqueString(resourceGroup().id)}'
var logAnalyticsWorkspaceName = '${applicationName}-la-${uniqueString(resourceGroup().id)}'
var applicationInsightsName = '${applicationName}-ai-${uniqueString(resourceGroup().id)}'
var keyVaultName = '${applicationName}-kv-${uniqueString(resourceGroup().id)}'
var storageAccountName = '${applicationName}stor${uniqueString(resourceGroup().id)}'

var mySQLServerName = '${applicationName}-mysql-${uniqueString(resourceGroup().id)}'
var databaseLogin = 'ghost'
var databaseName = 'ghost'

var ghostContentFileShareName = 'contentfiles'
var ghostContentFilesMountPath = '/var/lib/ghost/content_files'
var siteUrl = (deploymentConfiguration == 'Web app with Azure Front Door')
  ? 'https://${frontDoor!.outputs.frontDoorEndpointHostName}'
  : 'https://${webApp.outputs.hostName}'

//Web app with Azure Front Door
var frontDoorName = '${applicationName}-afd-${uniqueString(resourceGroup().id)}'

module vNet './modules/virtualNetwork.bicep' = {
  name: 'vNetDeploy'
  params: {
    vNetName: vNetName
    vNetAddressPrefix: vNetAddressPrefix
    privateEndpointsSubnetName: privateEndpointsSubnetName
    privateEndpointsSubnetPrefix: privateEndpointsSubnetPrefix
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
    storageAccountKind: 'StorageV2'
    storageAccountHttpsTrafficOnly: true
    fileShareFolderName: ghostContentFileShareName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    location: location
    vNetName: vNetName
    privateEndpointsSubnetName: privateEndpointsSubnetName
    applicationName: applicationName
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
    principalId: webApp.outputs.principalId
    principalName: webApp.outputs.principalName
    applicationName: webAppName
  }
  dependsOn: [
    vNet
    logAnalyticsWorkspace
  ]
}

module webApp './modules/webApp.bicep' = {
  name: 'webAppDeploy'
  params: {
    webAppName: webAppName
    appServicePlanName: appServicePlanName
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    vNetName: vNetName
    integrationSubnetName: webAppIntegrationSubnetName
    integrationSubnetPrefix: webAppIntegrationSubnetPrefix
  }
  dependsOn: [
    appServicePlan
    vNet
    logAnalyticsWorkspace
  ]
}

module webAppSettings './modules/webAppSettings.bicep' = {
  name: 'webAppSettingsDeploy'
  params: {
    webAppName: webAppName
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
    webApp
    frontDoor
    mySQLServer
  ]
}

module appServicePlan './modules/appServicePlan.bicep' = {
  name: 'appServicePlanDeploy'
  params: {
    appServicePlanName: appServicePlanName
    appServicePlanSku: appServicePlanSku
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName

  }
  dependsOn: [
    logAnalyticsWorkspace
  ]
}

module applicationInsights './modules/applicationInsights.bicep' = {
  name: 'applicationInsightsDeploy'
  params: {
    applicationInsightsName: applicationInsightsName
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  }
  dependsOn: [
    webApp
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
    applicationName: applicationName
  }
  dependsOn: [
    vNet
    logAnalyticsWorkspace
  ]
}

module frontDoor './modules/frontDoorStandard.bicep' = if (deploymentConfiguration == 'Web app with Azure Front Door') {
  name: 'FrontDoorDeploy'
  params: {
    frontDoorProfileName: frontDoorName
    applicationName: applicationName
    webAppName: webAppName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  }
  dependsOn: [
    webApp
    logAnalyticsWorkspace
  ]
}

output webAppHostName string = webApp.outputs.hostName
output endpointHostName string = siteUrl
