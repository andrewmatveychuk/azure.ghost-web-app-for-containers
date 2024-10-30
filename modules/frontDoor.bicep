targetScope = 'resourceGroup'

@minLength(5)
@maxLength(64)
param frontDoorName string

@minLength(1)
@maxLength(128)
param wafPolicyName string

@description('Log Analytics workspace to use for diagnostics settings')
param logAnalyticsWorkspaceName string

@description('Web app to confire Front Door for')
param webAppName string

var backendPool1Name = '${frontDoorName}-backendPool1'
var healthProbe1Name = '${frontDoorName}-healthProbe1'
var frontendEndpoint1Name = '${frontDoorName}-frontendEndpoint1'
var loadBalancing1Name = '${frontDoorName}-loadBalancing1'
var routingRule1Name = '${frontDoorName}-routingRule1'
var frontendEndpoint1hostName = '${frontDoorName}.azurefd.net'

resource existingWebApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: webAppName
}

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
          webApplicationFirewallPolicyLink: {
            id: wafPolicy.id
          }
        }
      }
    ]
    enabledState: 'Enabled'
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource frontDoorDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: frontDoor
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
    ]
  }
}

resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2024-02-01' = {
  name: wafPolicyName
  location: 'global'
  properties: {
    policySettings: {
      mode: 'Prevention'
      enabledState: 'Enabled'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '1.1'
        }
      ]
    }
  }
}

output frontendEndpointHostName string = frontendEndpoint1hostName
