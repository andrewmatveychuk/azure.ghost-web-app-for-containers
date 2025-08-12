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

@description('Container App deployment configuration')
@allowed([
  'Container app only (public access)'
  'Container app (private) with Azure Front Door Premium (private link access)'
])
param deploymentConfiguration string = 'Container app only (public access)'

@description('Virtual network address prefix to use')
param vNetAddressPrefix string = '10.0.0.0/22'
@description('Address prefix for private links subnet')
param privateEndpointsSubnetPrefix string = '10.0.3.240/28'
@description('Address prefix for integration subnet')
param integrationSubnetPrefix string = '10.0.0.0/27' // Minimal subnet size for Container App Environment with workload profiles

var ghostContentFileShareName = 'content-files'
var ghostContentFilesMountPath = '/var/lib/ghost/content_files'
/* var siteUrl = (deploymentConfiguration == 'Container app with Azure Front Door Premium')
? 'https://${frontDoor!.outputs.frontDoorEndpointHostName}'
: 'https://${containerApp.outputs.hostName}'
*/
//Web app with Azure Front Door

// Creating the virtual network and the subnet for private endpoints
var vNetName = '${applicationNamePrefix}-vnet-${uniqueString(resourceGroup().id)}'
var privateEndpointsSubnetName = 'pe-subnet'

module vNet 'modules/virtualNetwork.bicep' = {
  name: 'vNetDeploy'
  params: {
    vNetName: vNetName
    vNetAddressPrefix: vNetAddressPrefix
    privateEndpointsSubnetName: privateEndpointsSubnetName
    privateEndpointsSubnetPrefix: privateEndpointsSubnetPrefix
    location: location
  }
}

// Creating the Log Analytics workspace
var logAnalyticsWorkspaceName = '${applicationNamePrefix}-la-${uniqueString(resourceGroup().id)}'

module logAnalyticsWorkspace 'modules/logAnalyticsWorkspace.bicep' = {
  name: 'logAnalyticsWorkspaceDeploy'
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceSku: logAnalyticsWorkspaceSku
    location: location
  }
}

// Creating the Application Insights
var applicationInsightsName = '${applicationNamePrefix}-ai-${uniqueString(resourceGroup().id)}'

module applicationInsights 'modules/applicationInsights.bicep' = {
  name: 'applicationInsightsDeploy'
  params: {
    applicationInsightsName: applicationInsightsName
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  }
  dependsOn: [
    logAnalyticsWorkspace
  ]
}

// Creating the Storage account to be used as a persistent storage for the Container App
var storageAccountName = '${applicationNamePrefix}stor${uniqueString(resourceGroup().id)}'
var privateEndpointName = '${applicationNamePrefix}-pe-file-${uniqueString(resourceGroup().id)}'

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
    privateEndpointName: privateEndpointName
  }
  dependsOn: [
    vNet
    logAnalyticsWorkspace
  ]
}

// Creating the Managed Identity to be used by the Container App to access the Key Vault
var managedIdentityName = '${applicationNamePrefix}-mi-${uniqueString(resourceGroup().id)}'

module managedIdentity 'modules/managedIdentity.bicep' = {
  name: 'managedIdentityDeploy'
  params: {
    managedIdentityName: managedIdentityName
  }
}

// Creating the Key Vault to store the database password
var keyVaultName = '${applicationNamePrefix}-kv-${uniqueString(resourceGroup().id)}'

module keyVault 'modules/keyVault.bicep' = {
  name: 'keyVaultDeploy'
  params: {
    keyVaultName: keyVaultName
    keyVaultSecretName: 'databasePassword'
    keyVaultSecretValue: databasePassword
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    location: location
    vNetName: vNetName
    privateEndpointsSubnetName: privateEndpointsSubnetName
    principalId: managedIdentity.outputs.principalId
    principalName: managedIdentity.outputs.principalName
  }
  dependsOn: [
    vNet
    logAnalyticsWorkspace
  ]
}

// Creating the Container App Environment
var containerAppEnvironmentName = '${applicationNamePrefix}-cenv-${uniqueString(resourceGroup().id)}'
var containerAppEnvironmentStorageName = 'default' // Name of the storage to be used by the Container App Environment

module containerAppEnvironment 'modules/containerAppEnvironment.bicep' = {
  name: 'containerAppEnvironmentDeploy'
  params: {
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    applicationInsightsName: applicationInsightsName
    containerAppEnvironmentName: containerAppEnvironmentName
    integrationSubnetPrefix: integrationSubnetPrefix
    vNetName: vNetName
    internal: false
    containerAppEnvironmentStorageName: containerAppEnvironmentStorageName
    fileShareName: ghostContentFileShareName
    storageAccountName: storageAccountName
  }
  dependsOn: [
    logAnalyticsWorkspace
    applicationInsights
    vNet
    storageAccount
  ]
}

// Creating the Container App
var databaseLogin = applicationNamePrefix
var databaseName = applicationNamePrefix

var containerAppName = '${applicationNamePrefix}-capp-${uniqueString(resourceGroup().id)}'
var containerImageURL = '${containerRegistryName}/${ghostContainerName}'
var containerPort = 80 //2368 for Ghost, 80 for azuredocs sample
var containerVariables = [
  {
    name: 'NODE_ENV'
    value: 'development'
  }
  {
    name: 'GHOST_CONTENT'
    value: ghostContentFilesMountPath
  }
  {
    name: 'paths__contentPath'
    value: ghostContentFilesMountPath
  }
  {
    name: 'privacy_useUpdateCheck'
    value: 'false'
  }
  /* {
    name: 'url'
    value: ''
  } */
  {
    name: 'database__client'
    value: 'mysql'
  }
  {
    name: 'database__connection__host'
    value: mySQLServer.outputs.fullyQualifiedDomainName
  }
  {
    name: 'database__connection__database'
    value: databaseName
  }
  {
    name: 'database__connection__user'
    value: databaseLogin
  }
  {
    name: 'database__connection__password'
    secretRef: 'database-password'
  }
  {
    name: 'database__connection__ssl__ca'
    value: ''
  }
]

module containerApp 'modules/containerApp.bicep' = {
  name: 'containerAppDeploy'
  params: {
    containerAppEnvironmentName: containerAppEnvironmentName
    containerAppName: containerAppName
    containerImageUrl: containerImageURL
    containerPort: containerPort
    containerVolumes: [
      {
        name: ghostContentFileShareName
        storageName: containerAppEnvironmentStorageName
        storageType: 'AzureFile'
      }
    ]
    containerVolumeMounts: [
      {
        volumeName: ghostContentFileShareName
        mountPath: ghostContentFilesMountPath
      }
    ]
    containerEnvVars: containerVariables
    containerSecrets: [
      {
        name: 'database-password' // This should be lower case alphanumeric characters, '-', and must start and end with an alphanumeric character
        keyVaultUrl: keyVault.outputs.secretUri
        identity: managedIdentity.outputs.id
      }
    ]
    managedIdentityId: managedIdentity.outputs.id
  }
  dependsOn: [
    storageAccount
    containerAppEnvironment
  ]
}

// Creating the MySQL server and the database to be used by the Container App
var mySQLServerName = '${applicationNamePrefix}-mysql-${uniqueString(resourceGroup().id)}'

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

/* // Creating the Front Door profile if required by the deployment configuration
var frontDoorName = '${applicationNamePrefix}-afd-${uniqueString(resourceGroup().id)}'

module frontDoor 'modules/frontDoor.bicep' = if (deploymentConfiguration == 'Container app with Azure Front Door Premium') {
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
