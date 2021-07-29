targetScope = 'resourceGroup'

param webAppName string

param applicationInsightsInstrumentationKey string

param applicationInsightsConnectionString string

param databaseHostFQDN string

param databaseLogin string

param databasePasswordSecretUri string

param siteUrl string

param containerMountPath string

resource existingWebApp 'Microsoft.Web/sites@2020-09-01' existing = {
  name: webAppName
}

resource webAppSettings 'Microsoft.Web/sites/config@2021-01-15' = {
  parent: existingWebApp
  name: 'appsettings'
  properties: {
    APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsightsInstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsightsConnectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
    XDT_MicrosoftApplicationInsights_Mode: 'default'
    NODE_ENV: 'production'
    GHOST_CONTENT: containerMountPath
    paths__contentPath: containerMountPath
    privacy_useUpdateCheck: 'false'
    url: siteUrl
    database__client: 'mysql'
    database__connection__host: databaseHostFQDN
    database__connection__user: databaseLogin
    database__connection__password: '@Microsoft.KeyVault(SecretUri=${databasePasswordSecretUri})'
    database__connection__database: 'ghost'
    database__connection__ssl_rejectUnauthorized: 'true'
    database__connection__ssl_secureProtocol: 'TLSv1_2_method'
    WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'false'
    // WEBSITES_CONTAINER_START_TIME_LIMIT: '460'
    // WEBSITES_WEB_CONTAINER_NAME: 'ghost'
  }
}
