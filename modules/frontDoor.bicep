targetScope = 'resourceGroup'

@minLength(5)
@maxLength(64)
param frontDoorProfileName string

@description('Application name')
param applicationName string

@description('Log Analytics workspace to use for diagnostics settings')
param logAnalyticsWorkspaceName string

@description('Web app to confire Front Door for')
param webAppName string

var frontDoorEndpointName = '${applicationName}-Endpoint'
var frontDoorOriginGroupName = '${applicationName}-OriginGroup'
var frontDoorOriginName = '${applicationName}-Origin'
var frontDoorRouteName = '${applicationName}-Route'

resource frontDoorProfile 'Microsoft.Cdn/profiles@2024-02-01' = {
  name: frontDoorProfileName
  location: 'global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-02-01' = {
  name: frontDoorEndpointName
  parent: frontDoorProfile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2024-02-01' = {
  name: frontDoorOriginGroupName
  parent: frontDoorProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 2
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 120
    }
  }
}

resource existingWebApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: webAppName
}

resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = {
  name: frontDoorOriginName
  parent: frontDoorOriginGroup
  properties: {
    hostName: existingWebApp.properties.defaultHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: existingWebApp.properties.defaultHostName
    priority: 1
    weight: 1000
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-02-01' = {
  name: frontDoorRouteName
  parent: frontDoorEndpoint
  dependsOn: [
    frontDoorOrigin
  ]
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    /* cacheConfiguration: {
      compressionSettings:{
        isCompressionEnabled: true
      }
    } */
  }
}

/*
resource frontDoor 'Microsoft.Network/frontDoors@2021-06-01' = {
  name: frontDoorName
  location: 'global'
  properties: {
    routingRules: [
      {
        name: routingRule1Name
        properties: {
          frontendEndpoints: [
            {
              id: resourceId('Microsoft.Network/frontDoors/frontendEndpoints', frontDoorName, frontendEndpoint1Name)
            }
          ]
          acceptedProtocols: [
            'Http'
            'Https'
          ]
          patternsToMatch: [
            '/*'
          ]
          routeConfiguration: {
            '@odata.type': '#Microsoft.Azure.FrontDoor.Models.FrontdoorForwardingConfiguration'
            forwardingProtocol: 'HttpsOnly'
            backendPool: {
              id: resourceId('Microsoft.Network/frontDoors/backendPools', frontDoorName, backendPool1Name)
            }
            cacheConfiguration: {
              queryParameterStripDirective: 'StripNone'
              dynamicCompression: 'Enabled'
            }
          }
          enabledState: 'Enabled'
        }
      }
    ]
    healthProbeSettings: [
      {
        name: healthProbe1Name
        properties: {
          path: '/'
          protocol: 'Https'
          intervalInSeconds: 120
        }
      }
    ]
    loadBalancingSettings: [
      {
        name: loadBalancing1Name
        properties: {
          sampleSize: 4
          successfulSamplesRequired: 2
        }
      }
    ]
    backendPools: [
      {
        name: backendPool1Name
        properties: {
          backends: [
            {
              address: existingWebApp.properties.defaultHostName
              backendHostHeader: existingWebApp.properties.defaultHostName
              httpPort: 80
              httpsPort: 443
              weight: 50
              priority: 1
              enabledState: 'Enabled'
            }
          ]
          loadBalancingSettings: {
            id: resourceId('Microsoft.Network/frontDoors/loadBalancingSettings', frontDoorName, loadBalancing1Name)
          }
          healthProbeSettings: {
            id: resourceId('Microsoft.Network/frontDoors/healthProbeSettings', frontDoorName, healthProbe1Name)
          }
        }
      }
    ]
    frontendEndpoints: [
      {
        name: frontendEndpoint1Name
        properties: {
          hostName: frontendEndpoint1hostName
          sessionAffinityEnabledState: 'Disabled'
        }
      }
    ]
    enabledState: 'Enabled'
  }
} */

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource frontDoorDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: frontDoorProfile
  name: 'FrontDoorDiagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logs: [
      {
        category: 'FrontdoorAccessLog'
        enabled: true
      }
      {
        category: 'FrontdoorWebApplicationFirewallLog'
        enabled: true
      }
      {
        category: 'FrontdoorHealthProbeLog'
        enabled: true
      }
    ]
  }
}

resource siteConfig 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: existingWebApp
  name: 'web'
  properties: {
    ipSecurityRestrictions: [
      {
        ipAddress: 'AzureFrontDoor.Backend'
        action: 'Allow'
        tag: 'ServiceTag'
        priority: 100
        name: 'Allow traffic from Front Door'
        headers: {
          'x-azure-fdid': [
            frontDoorProfile.properties.frontDoorId
          ]
        }
      }
    ]
  }
}

output frontDoorEndpointHostName string = frontDoorEndpoint.properties.hostName
