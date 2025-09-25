targetScope = 'resourceGroup'

// General parameters
@minLength(5)
@maxLength(64)
param frontDoorProfileName string

@description('Application name')
param applicationName string

@description('Log Analytics workspace to use for diagnostics settings')
param logAnalyticsWorkspaceName string

@description('Container App Environment to configure Private Link service for')
param containerAppEnvironmentName string

@description('Resource type for the shared private link resource')
param sharedPrivateLinkResourceGroupId string = 'managedEnvironments' // This actually refers to the resource type, not the resource group

@allowed([
  'Detection'
  'Prevention'
])
@description('The mode that the WAF should be deployed using. In \'Prevention\' mode, the WAF will block requests it detects as malicious. In \'Detection\' mode, the WAF will not block requests and will simply log the request.')
param wafMode string = 'Prevention'

@description('The list of managed rule sets to configure on the WAF.')
param wafManagedRuleSets array = [
  {
    ruleSetType: 'Microsoft_DefaultRuleSet'
    ruleSetVersion: '2.1'
    ruleSetAction: 'Block'
  }
  {
    ruleSetType: 'Microsoft_BotManagerRuleSet'
    ruleSetVersion: '1.1'
  }
]


resource existingContainerEnvironment 'Microsoft.App/managedEnvironments@2025-02-02-preview' existing = {
  name: containerAppEnvironmentName
}

// Configuring Front Door profile and endpoint

var frontDoorEndpointName = applicationName
var frontDoorOriginGroupName = '${applicationName}-OriginGroup'
var frontDoorOriginName = '${applicationName}-Origin'
@description('A FQDN of the origin for Front Door')
param frontDoorOriginHostName string
var frontDoorRouteName = '${applicationName}-Route'
@description('Name of Azure Front Door pricing tier.')
param frontDoorSku string = 'Premium_AzureFrontDoor'

resource frontDoorProfile 'Microsoft.Cdn/profiles@2025-06-01' = {
  name: frontDoorProfileName
  location: 'global'
  sku: {
    name: frontDoorSku
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2025-06-01' = {
  name: frontDoorEndpointName
  parent: frontDoorProfile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2025-06-01' = {
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
    sessionAffinityState: 'Disabled'
  }
}

resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = {
  name: frontDoorOriginName
  parent: frontDoorOriginGroup
  properties: {
    hostName: frontDoorOriginHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: frontDoorOriginHostName
    priority: 1
    weight: 1000
    sharedPrivateLinkResource: {
      privateLink: {
        id: existingContainerEnvironment.id
      }
      privateLinkLocation: existingContainerEnvironment.location
      groupId: sharedPrivateLinkResourceGroupId
      status: 'Approved' // This private link connection still requires manual approval from the target resource, as it is not in the same tenant/subscription and cannot be auto-approved
      requestMessage: 'Please approve this request to allow Front Door to access the container app'
    }
    enforceCertificateNameCheck: true
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
    cacheConfiguration: {
      compressionSettings: {
        isCompressionEnabled: true
        contentTypesToCompress: [
          'application/eot'
          'application/font'
          'application/font-sfnt'
          'application/javascript'
          'application/json'
          'application/opentype'
          'application/otf'
          'application/pkcs7-mime'
          'application/truetype'
          'application/ttf'
          'application/vnd.ms-fontobject'
          'application/xhtml+xml'
          'application/xml'
          'application/xml+rss'
          'application/x-font-opentype'
          'application/x-font-truetype'
          'application/x-font-ttf'
          'application/x-httpd-cgi'
          'application/x-javascript'
          'application/x-mpegurl'
          'application/x-opentype'
          'application/x-otf'
          'application/x-perl'
          'application/x-ttf'
          'font/eot'
          'font/ttf'
          'font/otf'
          'font/opentype'
          'image/svg+xml'
          'text/css'
          'text/csv'
          'text/html'
          'text/javascript'
          'text/js'
          'text/plain'
          'text/richtext'
          'text/tab-separated-values'
          'text/xml'
          'text/x-script'
          'text/x-component'
          'text/x-java-source'
        ]
      }
      queryStringCachingBehavior: 'UseQueryString'
    }
  }
}

resource existingWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource frontDoorDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: frontDoorProfile
  name: 'FrontDoorDiagnostics'
  properties: {
    workspaceId: existingWorkspace.id
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

// Configuring WAF and security policy association
resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2025-03-01' = {
  name: applicationName
  location: 'global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      mode: wafMode
      requestBodyCheck: 'Enabled'
      enabledState: 'Enabled'
    }
    managedRules: {
      managedRuleSets: wafManagedRuleSets
    }
  }
}

resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2025-06-01' =  {
  name: applicationName
  parent: frontDoorProfile
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: [
            {
              id: frontDoorEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

output frontDoorEndpointHostName string = frontDoorEndpoint.properties.hostName
