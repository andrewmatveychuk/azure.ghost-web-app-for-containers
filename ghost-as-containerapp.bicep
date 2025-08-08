targetScope = 'resourceGroup'

@description('Prefix to use when creating the resources in this deployment.')
param applicationNamePrefix string = 'ghost'

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
// param ghostContainerName string = 'andrewmatveychuk/ghost-ai:latest'
param ghostContainerName string = 'azuredocs/containerapps-helloworld:latest'

@description('Container registry where the image is hosted')
// param containerRegistryName string = 'docker.io'
param containerRegistryName string = 'mcr.microsoft.com'

var containerImageURL = '${containerRegistryName}/${ghostContainerName}'
// var containerPort = 2368
var containerPort = 80

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
var delegatedServiceName = '' //'Microsoft.App/environments'

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
/* var siteUrl = (deploymentConfiguration == 'Container app with Azure Front Door Premium')
  ? 'https://${frontDoor!.outputs.frontDoorEndpointHostName}'
  : 'https://${containerApp.outputs.hostName}'
 */
//Web app with Azure Front Door
var frontDoorName = '${applicationNamePrefix}-afd-${uniqueString(resourceGroup().id)}'

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

/* module keyVault './modules/keyVault.bicep' = {
  name: 'keyVaultDeploy'
  params: {
    keyVaultName: keyVaultName
    keyVaultSecretName: 'databasePassword'
    keyVaultSecretValue: databasePassword
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    location: location
    vNetName: vNetName
    privateEndpointsSubnetName: privateEndpointsSubnetName
    principalId:
    principalName:
  }
  dependsOn: [
    // containerApp
    vNet
    logAnalyticsWorkspace
  ]
} */

module containerApp './modules/containerApp.bicep' = {
  name: 'containerAppDeploy'
  params: {
    containerAppEnvironmentName: containerAppEnvironmentName
    containerAppName: containerAppName
    containerImageUrl: containerImageURL
    containerPort: containerPort
  }
  dependsOn: [
    containerAppEnvironment
  ]
}


module containerAppEnvironment './modules/containerAppEnvironment.bicep' = {
  name: 'containerAppEnvironmentDeploy'
  params: {
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    applicationInsightsName: applicationInsightsName
    containerAppEnvironmentName: containerAppEnvironmentName
    integrationSubnetName: integrationSubnetName
    integrationSubnetPrefix: integrationSubnetPrefix
    vNetName: vNetName
    internal: true
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
    logAnalyticsWorkspace
  ]
}

/* module mySQLServer './modules/mySQLServer.bicep' = {
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
} */

/* module frontDoor './modules/frontDoor.bicep' = if (deploymentConfiguration == 'Container app with Azure Front Door Premium') {
  name: 'FrontDoorDeploy'
  params: {
    frontDoorProfileName: frontDoorName
    applicationName: applicationNamePrefix
    webAppName: containerAppName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  }
  dependsOn: [
    logAnalyticsWorkspace
  ]
} */

output hostName string = containerApp.outputs.hostName
// output endpointHostName string = siteUrl
