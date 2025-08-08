targetScope = 'resourceGroup'

@minLength(5)
@maxLength(64)
param frontDoorProfileName string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('Application name')
param applicationName string

@description('Log Analytics workspace to use for diagnostics settings')
param logAnalyticsWorkspaceName string

@description('Web app to configure Front Door for')
param webAppName string

param containerAppEnvironmentName string

var frontDoorEndpointName = applicationName
var frontDoorOriginGroupName = '${applicationName}-OriginGroup'
var frontDoorOriginName = '${applicationName}-Origin'
var frontDoorRouteName = '${applicationName}-Route'

var managedLoadBalancerName = 'capp-svc-lb' // This is hardcoded as a managed resource

resource existingContainerAppEnvironment 'Microsoft.App/managedEnvironments@2025-02-02-preview' existing = {
  name: containerAppEnvironmentName
}

// ME_ghost-cenv-227pxybnua5y2_ghost-5-rg_westeurope
var managedLoadBalancerResourceGroupName = 'ME_${containerAppEnvironmentName}_${resourceGroup().name}_${existingContainerAppEnvironment.location}'

output appEnvironmentResourceGroupName string = managedLoadBalancerResourceGroupName

resource loadBalancer 'Microsoft.Network/loadBalancers@2023-11-01' existing = {
  name: managedLoadBalancerName
  scope: resourceGroup(managedLoadBalancerResourceGroupName)
}

// Configuring private link service for Front Door
@description('Virtual network for a private endpoint')
param vNetName string
@description('Target subnet to create a private endpoint')
param privateEndpointsSubnetName string
@description('Name of the pricing tier.')
param frontDoorSku string = 'Premium_AzureFrontDoor'

resource existingVNet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vNetName
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  name: privateEndpointsSubnetName
  parent: existingVNet
}

var privateLinkServiceName = '${applicationName}-pls-${uniqueString(resourceGroup().id)}'

resource privateLinkService 'Microsoft.Network/privateLinkServices@2024-07-01' = {
  name: privateLinkServiceName
  location: location
  properties: {
    autoApproval: {
      subscriptions: [
        subscription().subscriptionId
      ]
    }
    visibility: {
      subscriptions: [
        subscription().subscriptionId
      ]
    }
    fqdns: []
    enableProxyProtocol: false
    loadBalancerFrontendIpConfigurations: [
      {
        id: '${loadBalancer.id}/frontendIPConfigurations/${loadBalancer.name}fe'
      }
    ]
    ipConfigurations: [
      {
        name: 'ipconfig-0'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: existingSubnet.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
  }
}

// Configuring Front Door profile and endpoint

//++
resource frontDoorProfile 'Microsoft.Cdn/profiles@2025-06-01' = {
  name: frontDoorProfileName
  location: 'global'
  sku: {
    name: frontDoorSku
  }
}

//++
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
    sharedPrivateLinkResource: {
      privateLink: {
        id: privateLinkService.id
      }
      privateLinkLocation: privateLinkService.location
      status: 'Approved'
      requestMessage: 'Please approve this request to allow Front Door to access the container app'
    }
    enforceCertificateNameCheck: true
  }
}
//++
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
            frontDoorProfile.properties.frontDoorId //Scoping access to a unique Front Door instance
          ]
        }
      }
    ]
  }
}

output frontDoorEndpointHostName string = frontDoorEndpoint.properties.hostName
