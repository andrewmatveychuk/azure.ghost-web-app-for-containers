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
  'Web app only'
  'Web app with Azure Front Door'
])
param deploymentConfiguration string = 'Web app only'

@description('Virtual network address prefix to use')
param vnetAddressPrefix string = '10.0.0.0/26'
@description('Address prefix for web app integration subnet')
param webAppIntegrationSubnetPrefix string = '10.0.0.0/28'
@description('Address prefix for private links subnet')
param privateEndpointsSubnetPrefix string = '10.0.0.16/28'

var vNetName = '${applicationNamePrefix}-vnet-${uniqueString(resourceGroup().id)}'
var privateEndpointsSubnetName = 'privateEndpointsSubnet'
var webAppIntegrationSubnetName = 'webAppIntegrationSubnet'
var webAppName = '${applicationNamePrefix}-web-${uniqueString(resourceGroup().id)}'
var appServicePlanName = '${applicationNamePrefix}-asp-${uniqueString(resourceGroup().id)}'
var logAnalyticsWorkspaceName = '${applicationNamePrefix}-la-${uniqueString(resourceGroup().id)}'
var applicationInsightsName = '${applicationNamePrefix}-ai-${uniqueString(resourceGroup().id)}'
var keyVaultName = '${applicationNamePrefix}-kv-${uniqueString(resourceGroup().id)}'
var storageAccountName = '${applicationNamePrefix}stor${uniqueString(resourceGroup().id)}'

var mySQLServerName = '${applicationNamePrefix}-mysql-${uniqueString(resourceGroup().id)}'
var databaseLogin = 'ghost'
var databaseName = 'ghost'

var ghostContentFileShareName = 'contentfiles'
var ghostContentFilesMountPath = '/var/lib/ghost/content_files'
var siteUrl = (deploymentConfiguration == 'Web app with Azure Front Door') ? frontDoor.outputs.frontDoorEndpointHostName : webApp.outputs.hostName


//Web app with Azure Front Door
var frontDoorName = '${applicationNamePrefix}-afd-${uniqueString(resourceGroup().id)}'

module vNet 'modules/virtualNetwork.bicep' = {
  name: 'vNetDeploy'
  params: {
    vNetName: vNetName
    vNetAddressPrefix: vnetAddressPrefix
    privateEndpointsSubnetName: privateEndpointsSubnetName
    privateEndpointsSubnetPrefix: privateEndpointsSubnetPrefix
    webAppIntegrationSubnetName: webAppIntegrationSubnetName
    webAppIntegrationSubnetPrefix: webAppIntegrationSubnetPrefix
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

module storageAccount 'modules/storageAccount.bicep' = {
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
    servicePrincipalId: webApp.outputs.principalId
    location: location
    vNetName: vNetName
    privateEndpointsSubnetName: privateEndpointsSubnetName
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
    appServicePlanId: appServicePlan.outputs.id
    ghostContainerImage: ghostContainerName
    storageAccountName: storageAccountName
    fileShareName: ghostContentFileShareName
    containerMountPath: ghostContentFilesMountPath
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    vNetName: vNetName
    webAppIntegrationSubnetName: webAppIntegrationSubnetName
  }
  dependsOn: [
    appServicePlan
    vNet
    logAnalyticsWorkspace
    storageAccount
  ]
}

module webAppSettings 'modules/webAppSettings.bicep' = {
  name: 'webAppSettingsDeploy'
  params: {
    webAppName: webApp.outputs.name
    applicationInsightsConnectionString: applicationInsights.outputs.ConnectionString
    applicationInsightsInstrumentationKey: applicationInsights.outputs.InstrumentationKey
    containerRegistryUrl: containerRegistryUrl
    containerMountPath: ghostContentFilesMountPath
    databaseHostFQDN: mySQLServer.outputs.fullyQualifiedDomainName
    // databaseLogin: '${databaseLogin}@${mySQLServer.outputs.name}'
    databaseLogin: databaseLogin
    databasePasswordSecretUri: keyVault.outputs.secretUri
    databaseName: databaseName
    siteUrl: siteUrl
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
    vNet
    logAnalyticsWorkspace
  ]
}

module applicationInsights './modules/applicationInsights.bicep' = {
  name: 'applicationInsightsDeploy'
  params: {
    applicationInsightsName: applicationInsightsName
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    webAppName: webAppName
  }
  dependsOn: [
    webApp
    logAnalyticsWorkspace
  ]
}

module mySQLServer 'modules/mySQLServer.bicep' = {
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


module frontDoor 'modules/frontDoor.bicep' = if (deploymentConfiguration == 'Web app with Azure Front Door') {
  name: 'FrontDoorDeploy'
  params: {
    frontDoorProfileName: frontDoorName
    applicationName: applicationNamePrefix
    webAppName: webApp.outputs.name
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  }
}

output webAppName string = webApp.outputs.name
output webAppPrincipalId string = webApp.outputs.principalId
output webAppHostName string = webApp.outputs.hostName
output mySQLServerFQDN string = mySQLServer.outputs.fullyQualifiedDomainName

var endpointHostName = (deploymentConfiguration == 'Web app with Azure Front Door') ? frontDoor.outputs.frontDoorEndpointHostName : webApp.outputs.hostName

output endpointHostName string = endpointHostName
