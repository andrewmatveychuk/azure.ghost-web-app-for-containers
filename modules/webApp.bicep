targetScope = 'resourceGroup'

@minLength(2)
@maxLength(60)
param webAppName string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('App Service Plan id to host the app')
param appServicePlanId string

@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsWorkspaceId string

resource webApp 'Microsoft.Web/sites@2020-09-01' = {
  name: webAppName
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    clientAffinityEnabled: false
    serverFarmId: appServicePlanId
    httpsOnly: true
    enabled: true
    reserved: true
    siteConfig: {
      http20Enabled: true
      httpLoggingEnabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      linuxFxVersion: 'COMPOSE|dmVyc2lvbjogJzMuOCcKCnNlcnZpY2VzOgogICBkYjoKICAgIGltYWdlOiBteXNxbDo1LjcKICAgIHZvbHVtZXM6CiAgICAgICMgU2VlIGh0dHBzOi8vZG9jcy5taWNyb3NvZnQuY29tL2VuLXVzL2F6dXJlL2FwcC1zZXJ2aWNlL2NvbmZpZ3VyZS1jdXN0b20tY29udGFpbmVyP3Bpdm90cz1jb250YWluZXItbGludXgjY29uZmlndXJlLW11bHRpLWNvbnRhaW5lci1hcHBzCiAgICAgIC0gJHtXRUJBUFBfU1RPUkFHRV9IT01FfS9zaXRlL3d3d3Jvb3QvbXlzcWw6L3Zhci9saWIvbXlzcWwKICAgIHJlc3RhcnQ6IGFsd2F5cwogICAgZW52aXJvbm1lbnQ6CiAgICAgIE1ZU1FMX1JPT1RfSE9TVDogIiUiCiAgICAgICMgRmV0Y2hpbmcgdGhlIHBhc3N3b3JkIGZyb20gdGhlIGFwcGxpY2F0aW9uIHNldHRpbmdzCiAgICAgIE1ZU1FMX1JPT1RfUEFTU1dPUkQ6ICR7REFUQUJBU0VfUEFTU1dPUkR9CgogICBnaG9zdDoKICAgIGltYWdlOiBhbmRyZXdtYXR2ZXljaHVrL2dob3N0LWFpOmxhdGVzdAogICAgZGVwZW5kc19vbjoKICAgICAgLSBkYgogICAgY29tbWFuZDogWyIuL3dhaXQtZm9yLWl0LnNoIiwgImRiOjMzMDYiLCAiLS0iXQogICAgdm9sdW1lczoKICAgICAgLSAke1dFQkFQUF9TVE9SQUdFX0hPTUV9L3NpdGUvd3d3cm9vdC9jb250ZW50X2ZpbGVzOi92YXIvbGliL2dob3N0L2NvbnRlbnRfZmlsZXMKICAgIHJlc3RhcnQ6IGFsd2F5cwogICAgcG9ydHM6CiAgICAgIC0gODA6MjM2OAogICAgZW52aXJvbm1lbnQ6CiAgICAgICMgU2VlIGh0dHBzOi8vZG9jcy5naG9zdC5vcmcvZG9jcy9jb25maWcjc2VjdGlvbi1ydW5uaW5nLWdob3N0LXdpdGgtY29uZmlnLWVudi12YXJpYWJsZXMKICAgICAgZGF0YWJhc2VfX2NsaWVudDogbXlzcWwKICAgICAgZGF0YWJhc2VfX2Nvbm5lY3Rpb25fX2hvc3Q6IGRiCiAgICAgIGRhdGFiYXNlX19jb25uZWN0aW9uX191c2VyOiByb290CiAgICAgIGRhdGFiYXNlX19jb25uZWN0aW9uX19wYXNzd29yZDogJHtEQVRBQkFTRV9QQVNTV09SRH0KICAgICAgZGF0YWJhc2VfX2Nvbm5lY3Rpb25fX2RhdGFiYXNlOiBnaG9zdA=='
      alwaysOn: true
      use32BitWorkerProcess: false
    }
  }
}

resource webAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: webApp
  name: 'WebAppDiagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
      {
        category: 'AppServiceFileAuditLogs'
        enabled: true
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
      }
      {
        category: 'AppServiceIPSecAuditLogs'
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
      }
      {
        category: 'AppServiceAntivirusScanAuditLogs'
        enabled: true
      }
    ]
  }
}

output name string = webApp.name
output hostName string = webApp.properties.hostNames[0]
output principalId string = webApp.identity.principalId
