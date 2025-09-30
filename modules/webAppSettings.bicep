targetScope = 'resourceGroup'

@description('Web app to configure settings')
param webAppName string

@description('Application Insights to use by web app')
param applicationInsightsName string

@description('MySQL server name')
param mySQLServerName string

@description('Ghost database name')
param databaseName string

@description('Ghost database user name')
param databaseLogin string

@description('Ghost database user password')
param databasePasswordSecretUri string

@description('Website URL to autogenerate links by Ghost')
param siteUrl string

@description('Container registry to pull Ghost docker image')
param containerRegistryUrl string

@description('Ghost container full image name and tag')
param ghostContainerImage string

@description('Storage account name to store Ghost content files')
param storageAccountName string

@description('File share name on the storage account to store Ghost content files')
param fileShareName string

@description('Path to mount the file share in the container')
param containerMountPath string

var containerImageReference = 'DOCKER|${ghostContainerImage}'

resource existingStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource existingWebApp 'Microsoft.Web/sites@2020-09-01' existing = {
  name: webAppName
}

resource existingApplicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource existingMySQLServer 'Microsoft.DBforMySQL/flexibleServers@2023-12-30' existing = {
  name: mySQLServerName
}

resource siteConfig 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: existingWebApp
  name: 'web'
  properties: {
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
        accountName: existingStorageAccount.name
        shareName: fileShareName
        mountPath: containerMountPath
        accessKey: existingStorageAccount.listKeys().keys[0].value
      }
    }
  }
}

resource appSettings 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: existingWebApp
  name: 'appsettings'
  properties: {
    APPLICATIONINSIGHTS_CONNECTION_STRING: existingApplicationInsights.properties.ConnectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
    XDT_MicrosoftApplicationInsights_Mode: 'default'
    WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'false'
    DOCKER_REGISTRY_SERVER_URL: containerRegistryUrl
    // Ghost-specific settings
    NODE_ENV: 'production'
    GHOST_CONTENT: containerMountPath
    paths__contentPath: containerMountPath
    privacy_useUpdateCheck: 'false'
    url: siteUrl
    database__client: 'mysql'
    database__connection__host: existingMySQLServer.properties.fullyQualifiedDomainName
    database__connection__user: databaseLogin
    database__connection__password: '@Microsoft.KeyVault(SecretUri=${databasePasswordSecretUri})'
    database__connection__database: databaseName
    database__connection__ssl__ca: '''
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
}
