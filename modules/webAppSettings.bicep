targetScope = 'resourceGroup'

param webAppName string

param applicationInsightsInstrumentationKey string

param applicationInsightsConnectionString string

param databasePasswordSecretUri string

param siteUrl string

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
    GHOST_CONTENT: '/var/lib/ghost/content_files/'
    paths__contentPath: '/var/lib/ghost/content_files/'
    privacy_useUpdateCheck: 'false'
    url: siteUrl
    WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'true'
    WEBSITES_CONTAINER_START_TIME_LIMIT: '460'
    WEBSITES_WEB_CONTAINER_NAME: 'ghost'
    DATABASE_PASSWORD: '@Microsoft.KeyVault(SecretUri=${databasePasswordSecretUri})'
  }
}
