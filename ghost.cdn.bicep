targetScope = 'resourceGroup'

@description('Prefix to use when creating the resources in this deployment.')
param applicationNamePrefix string = 'ghost'

@description('Pricing tier for the App Service Plan')
param appServicePlanSku string = 'B1'

@description('Pricing tier for the Log Analytics workspace')
param logAnalyticsWorkspaceSku string = 'Free'

@description('Pricing tier for the CDN Profile')
param cdnProfileSku object = {
  name: 'Standard_Microsoft'
}

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('MySQL server password')
@secure()
param databasePassword string

@description('MySQL Flexible Server SKU')
param mySQLServerSku string = 'Standard_B1s'

var webAppName = '${applicationNamePrefix}-web-${uniqueString(resourceGroup().id)}'
var appServicePlanName = '${applicationNamePrefix}-asp-${uniqueString(resourceGroup().id)}'
var logAnalyticsWorkspaceName = '${applicationNamePrefix}-la-${uniqueString(resourceGroup().id)}'
var applicationInsightsName = '${applicationNamePrefix}-ai-${uniqueString(resourceGroup().id)}'
var keyVaultName = '${applicationNamePrefix}-kv-${uniqueString(resourceGroup().id)}'
var mySQLServerName = '${applicationNamePrefix}-mysql-${uniqueString(resourceGroup().id)}'
var cdnProfileName = '${applicationNamePrefix}-cdnp-${uniqueString(resourceGroup().id)}'
var cdnEndpointName = '${applicationNamePrefix}-cdne-${uniqueString(resourceGroup().id)}'

module logAnalyticsWorkspace './modules/logAnalyticsWorkspace.bicep' = {
  name: 'logAnalyticsWorkspaceDeploy'
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceSku: logAnalyticsWorkspaceSku
    location: location
  }
}

module keyVault './modules/keyVault.bicep' = {
  name: 'keyVaultDeploy'
  params: {
    keyVaultName: keyVaultName
    keyVaultSecretName: 'databasePassword'
    keyVaultSecretValue: databasePassword
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    servicePrincipalId: webApp.outputs.principalId
    location: location
  }
}

module webApp './modules/webApp.bicep' = {
  name: 'webAppDeploy'
  params: {
    webAppName: webAppName
    appServicePlanId: appServicePlan.outputs.id
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
  }
}

module webAppSettings 'modules/webAppSettings.bicep' = {
  name: 'webAppSettingsDeploy'
  params: {
    webAppName: webApp.outputs.name
    applicationInsightsConnectionString: applicationInsights.outputs.ConnectionString
    applicationInsightsInstrumentationKey: applicationInsights.outputs.InstrumentationKey
    databasePasswordSecretUri: keyVault.outputs.databasePasswordSecretUri
    siteUrl: 'https://${cdnEndpointName}.azureedge.net'
  }
}

module appServicePlan './modules/appServicePlan.bicep' = {
  name: 'appServicePlanDeploy'
  params: {
    appServicePlanName: appServicePlanName
    appServicePlanSku: appServicePlanSku
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
  }
}

module applicationInsights './modules/applicationInsights.bicep' = {
  name: 'applicationInsightsDeploy'
  params: {
    applicationInsightsName: applicationInsightsName
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
  }
}

module mySQLServer 'modules/mySQLServer.bicep' = {
  name: 'mySQLServerDeploy'
  params: {
    administratorLogin: 'ghost'
    administratorPassword: databasePassword
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    mySQLServerName: mySQLServerName
    mySQLServerSku: mySQLServerSku
  }
}

module cdnEndpoint './modules/cdnEndpoint.bicep' = {
  name: 'cdnEndPointDeploy'
  params: {
    cdnProfileName: cdnProfileName
    cdnProfileSku: cdnProfileSku
    cdnEndpointName: cdnEndpointName
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    webAppName: webApp.name
    webAppHostName: webApp.outputs.hostName
  }
}

output webAppName string = webApp.outputs.name
output webAppPrincipalId string = webApp.outputs.principalId
output cdnEndpointOrigin string = cdnEndpoint.outputs.cdnEndpointOrigin
output cdnEndpointHostName string = cdnEndpoint.outputs.cdnEndpointHostName
