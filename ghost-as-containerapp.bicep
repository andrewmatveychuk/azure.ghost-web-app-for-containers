targetScope = 'resourceGroup'

@description('Prefix to use when creating the resources in this deployment.')
param applicationName string = 'ghost'

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('Container App deployment configuration')
@allowed([
  'Container app only (public access)'
  'Container app (private) with Azure Front Door Premium (private link access)'
])
param deploymentConfiguration string = 'Container app only (public access)'

/* var siteUrl = (deploymentConfiguration == 'Container app with Azure Front Door Premium')
? 'https://${frontDoor!.outputs.frontDoorEndpointHostName}'
: 'https://${containerApp.outputs.hostName}'
*/
//Web app with Azure Front Door

// Creating the virtual network and the subnet for private endpoints
@description('Virtual network address prefix to use')
param vNetAddressPrefix string = '10.0.0.0/22'
@description('Address prefix for private links subnet')
param privateEndpointsSubnetPrefix string = '10.0.3.240/28'
@description('Address prefix for integration subnet')
param integrationSubnetPrefix string = '10.0.0.0/27' // Minimal subnet size for Container App Environment with workload profiles

var vNetName = '${applicationName}-vnet-${uniqueString(resourceGroup().id)}'
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
@description('Log Analytics workspace pricing tier')
param logAnalyticsWorkspaceSku string = 'PerGB2018'

var logAnalyticsWorkspaceName = '${applicationName}-la-${uniqueString(resourceGroup().id)}'

module logAnalyticsWorkspace 'modules/logAnalyticsWorkspace.bicep' = {
  name: 'logAnalyticsWorkspaceDeploy'
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceSku: logAnalyticsWorkspaceSku
    location: location
  }
}

// Creating the Application Insights
var applicationInsightsName = '${applicationName}-ai-${uniqueString(resourceGroup().id)}'

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
@description('Storage account pricing tier')
param storageAccountSku string = 'Standard_LRS'

var ghostContentFileShareName = 'content-files'

var storageAccountName = '${applicationName}stor${uniqueString(resourceGroup().id)}'
var privateEndpointName = '${applicationName}-pe-file-${uniqueString(resourceGroup().id)}'

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
    applicationName: applicationName
  }
  dependsOn: [
    vNet
    logAnalyticsWorkspace
  ]
}

// Creating the Managed Identity to be used by the Container App to access the Key Vault
var managedIdentityName = '${applicationName}-mi-${uniqueString(resourceGroup().id)}'

module managedIdentity 'modules/managedIdentity.bicep' = {
  name: 'managedIdentityDeploy'
  params: {
    managedIdentityName: managedIdentityName
  }
}

// Creating the Key Vault to store the database password
var keyVaultName = '${applicationName}-kv-${uniqueString(resourceGroup().id)}'

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
    applicationName: applicationName
  }
  dependsOn: [
    vNet
    logAnalyticsWorkspace
  ]
}

// Creating the Container App Environment
var containerAppEnvironmentName = '${applicationName}-cenv-${uniqueString(resourceGroup().id)}'
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

@description('Ghost container full image name and tag')
// param ghostContainerName string = 'andrewmatveychuk/ghost-ai:latest'
param ghostContainerName string = 'azuredocs/containerapps-helloworld:latest'

@description('Container registry where the image is hosted')
// param containerRegistryName string = 'docker.io'
param containerRegistryName string = 'mcr.microsoft.com'

var containerImageURL = '${containerRegistryName}/${ghostContainerName}'

var ghostContentFilesMountPath = '/var/lib/ghost/content_files'

var databaseLogin = applicationName
var databaseName = applicationName

var containerAppName = '${applicationName}-capp-${uniqueString(resourceGroup().id)}'
var containerPort = 80 //2368 for Ghost, 80 for azuredocs sample
var containerProbes = [
  {
    type: 'Liveness'
    httpGet: {
      path: '/'
      port: containerPort
    }
    initialDelaySeconds: 10
    periodSeconds: 5
  }
  {
    type: 'Readiness'
    tcpSocket: {
      port: containerPort
    }
    initialDelaySeconds: 10
    periodSeconds: 3
  }
  {
    type: 'Startup'
    tcpSocket: {
      port: containerPort
    }
    initialDelaySeconds: 30
    periodSeconds: 5
  }
]

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
    // https://learn.microsoft.com/en-us/azure/mysql/flexible-server/concepts-root-certificate-rotation
    name: 'database__connection__ssl__ca'
    value: '''
-----BEGIN CERTIFICATE-----
MIIDrzCCApegAwIBAgIQCDvgVpBCRrGhdWrJWZHHSjANBgkqhkiG9w0BAQUFADBh
MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
d3cuZGlnaWNlcnQuY29tMSAwHgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBD
QTAeFw0wNjExMTAwMDAwMDBaFw0zMTExMTAwMDAwMDBaMGExCzAJBgNVBAYTAlVT
MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
b20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBSb290IENBMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4jvhEXLeqKTTo1eqUKKPC3eQyaKl7hLOllsB
CSDMAZOnTjC3U/dDxGkAV53ijSLdhwZAAIEJzs4bg7/fzTtxRuLWZscFs3YnFo97
nh6Vfe63SKMI2tavegw5BmV/Sl0fvBf4q77uKNd0f3p4mVmFaG5cIzJLv07A6Fpt
43C/dxC//AH2hdmoRBBYMql1GNXRor5H4idq9Joz+EkIYIvUX7Q6hL+hqkpMfT7P
T19sdl6gSzeRntwi5m3OFBqOasv+zbMUZBfHWymeMr/y7vrTC0LUq7dBMtoM1O/4
gdW7jVg/tRvoSSiicNoxBN33shbyTApOB6jtSj1etX+jkMOvJwIDAQABo2MwYTAO
BgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUA95QNVbR
TLtm8KPiGxvDl7I90VUwHwYDVR0jBBgwFoAUA95QNVbRTLtm8KPiGxvDl7I90VUw
DQYJKoZIhvcNAQEFBQADggEBAMucN6pIExIK+t1EnE9SsPTfrgT1eXkIoyQY/Esr
hMAtudXH/vTBH1jLuG2cenTnmCmrEbXjcKChzUyImZOMkXDiqw8cvpOp/2PV5Adg
06O/nVsJ8dWO41P0jmP6P6fbtGbfYmbW0W5BjfIttep3Sp+dWOIrWcBAI+0tKIJF
PnlUkiaY4IBIqDfv8NZ5YBberOgOzW6sRBc4L0na4UU+Krk2U886UAb3LujEV0ls
YSEY1QSteDwsOoBrp+uvFRTp2InBuThs4pFsiv9kuXclVzDAGySj4dzp30d8tbQk
CAUw7C29C79Fv1C5qfPrmAESrciIxpg0X40KPMbp1ZWVbd4=
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIDjjCCAnagAwIBAgIQAzrx5qcRqaC7KGSxHQn65TANBgkqhkiG9w0BAQsFADBh
MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
d3cuZGlnaWNlcnQuY29tMSAwHgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBH
MjAeFw0xMzA4MDExMjAwMDBaFw0zODAxMTUxMjAwMDBaMGExCzAJBgNVBAYTAlVT
MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
b20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBSb290IEcyMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuzfNNNx7a8myaJCtSnX/RrohCgiN9RlUyfuI
2/Ou8jqJkTx65qsGGmvPrC3oXgkkRLpimn7Wo6h+4FR1IAWsULecYxpsMNzaHxmx
1x7e/dfgy5SDN67sH0NO3Xss0r0upS/kqbitOtSZpLYl6ZtrAGCSYP9PIUkY92eQ
q2EGnI/yuum06ZIya7XzV+hdG82MHauVBJVJ8zUtluNJbd134/tJS7SsVQepj5Wz
tCO7TG1F8PapspUwtP1MVYwnSlcUfIKdzXOS0xZKBgyMUNGPHgm+F6HmIcr9g+UQ
vIOlCsRnKPZzFBQ9RnbDhxSJITRNrw9FDKZJobq7nMWxM4MphQIDAQABo0IwQDAP
BgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBhjAdBgNVHQ4EFgQUTiJUIBiV
5uNu5g/6+rkS7QYXjzkwDQYJKoZIhvcNAQELBQADggEBAGBnKJRvDkhj6zHd6mcY
1Yl9PMWLSn/pvtsrF9+wX3N3KjITOYFnQoQj8kVnNeyIv/iPsGEMNKSuIEyExtv4
NeF22d+mQrvHRAiGfzZ0JFrabA0UWTW98kndth/Jsw1HKj2ZL7tcu7XUIOGZX1NG
Fdtom/DzMNU+MeKNhJ7jitralj41E6Vf8PlwUHBHQRFXGU7Aj64GxJUTFy8bJZ91
8rGOmaFvE7FBcf6IKshPECBV1/MUReXgRPTqh5Uykw7+U0b6LJ3/iyK5S9kJRaTe
pLiaWN0bfVKfjllDiIGknibVb63dDcY3fe0Dkhvld1927jyNxF1WW6LZZm6zNTfl
MrY=
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MD8FPzA/Az8/AwIBAgIQHj8JXz8/R3AePz9/RT8wDQYJKj9IPz8NAQEMBQAwZTELMAkGA1UEBhMC
VVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjE2MDQGA1UEAxMtTWljcm9zb2Z0IFJT
QSBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDE3MB4XDTE5MTIxODIyNTEyMloXDTQyMDcx
ODIzMDAyM1owZTELMAkGA1UEBhMCVVMxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjE2
MDQGA1UEAxMtTWljcm9zb2Z0IFJTQSBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDE3MD8C
IjANBgkqP0g/Pw0BAQEFAAM/Ag8AMD8CCgI/AgEAP1s/PzM/KT8/Fgo/P0diPz8/Nj9GPz8/eGpv
Rz9oPydnUDMdPz8/Pz9DPz8CVwFdP0hAP1MQPz8/O2g/Pz8tPz9lPz9tGT8/ez9KPz8OP0tDHT8H
PxM/Pz9kNTkEPz8/bD8/H1A/OGVQXBdGPz8/Pxw/Fz8/RT8/Jj8/P3BKP2A/Pz8/Pzs/V3I/Pz8/
P0trPyNsAz8FPz8/P3M7Zj9kPxo/Lj9HBT8GPz9zP3gzWz8/Jyo/Pz8/Pz8/Oj8+dkA/P1JhUXAo
Pz8/Wj8/ST8UW00/P2dNTBI/Pz8/eD8/Pz8/XiA/P0siPz8/Pz9HP0dVez9FP2coPz8caDA/P0k/
NXtkPz8/TT87PlU/KD9XPxM/Ric/Hj9eRD8/Pz8/Ez9LPz8/Pz9hP1IwP3ogT28POFM/MwwTKz8/
Pyo/LT8cfUtRP0c/SCdyXT8/P0U/SGU/P1I/P1s/GGVXEj9oPz8Vaz8/aSI/PzM/Pz9RP0FQPzRP
dj8/Pzg/Pz97Pz8/P0ZpPw4KUGsTPz8PN1o/Ej8/Px5WP1ciPz8/Pz8/UT87P1U/Hg4/dAo/Pz9p
Pz8oP0g/Bz9SQzo/P1U1LD8/aj8/Pz8/Emo/RT9nPz8/Iz8/ClQ/FD8qPz8/Pz8/JVgyeT8/Wz85
PwgGPz9/Dj0APwIDAQABP1QwUjAOBgNVHQ8BAT8EBAMCAT8wDwYDVR0TAQE/BAUwAwEBPzAdBgNV
HQ4EFgQUCT9Zfz8/cD8aPzk/Pz8/TT8jMBAGCSsGAQQBPzcVAQQDAgEAMA0GCSo/SD8/DQEBDAUA
Az8CAQA/Pz5dPxE/Pz8/Pz8VPxM/P0IuAj8WBVknPyA/Pxo/TT8/Vj9lQz8/AD9SP1U/UzltYkw/
DVt8LkQ/PxA/P1M/Pz9POj9uET8/PxY/Pz9tP380dD8/Pz8/Pz9kPz8/Pz8JUzM/Pwo/SlE/b1U/
Pz8/Rj8/fz9QJWVgP0Y/MwQ/bD8/dFQlPz8/P1UVPT9tPwo/Ej9pP24/ZD9TPz9KdSA/Pw8/Pz8D
P1kYP0c/P1daPz8/PxcrF0k/dj8/Vj86Nz8/aSw/Pz8/P0w/N3ZNPz8/bR4dPz8/Pz9FHRNtPz9Z
PyIncis/P1c/MD8kTT99Vj8/Pz80eT8/Pz8CYT8/Pw8/HBcLP0E/fD8nPz8uOj8/P3MdJD8/WyA/
Pz9nZnk/Oj8/Mz9TPz9GPxE/P38/Pz9mMSBBED8tDD8/PzQ/P2Q/PxNXPz8/PHo/Pz8/PyE/cT8/
Z3ESPwppGWQ/I1Y/PyoucD9mPww/Pz8/AT9qPz9nSz9oPz9iPz8/P3o7Xg8/P3w/Nz90Pz9PM3I/
OW0/Ej8/DE5wfBtvPz8yP3NEFm0/Pz8/Pz8/P104Pz8/PwowPz8/TQBxYkUnSzpCP1t/ZT9nNFIt
PxZrPz8/ez9CTHE/DD8+Pz8/ATBeUT95P3BpP0FEDz8/LD8/PT8PPw==
-----END CERTIFICATE-----'''
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
    containerProbes: containerProbes
  }
  dependsOn: [
    storageAccount
    containerAppEnvironment
  ]
}

// Creating the MySQL server and the database to be used by the Container App
@description('MySQL server SKU')
param mySQLServerSku string = 'Standard_B1ms'

@description('MySQL server password')
@secure()
param databasePassword string

var mySQLServerName = '${applicationName}-mysql-${uniqueString(resourceGroup().id)}'

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
    applicationName: applicationName
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

output testValue string = 'some text here'
output applicationHostName string = containerApp.outputs.hostName
// output endpointHostName string = siteUrl
