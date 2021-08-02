targetScope = 'resourceGroup'

@description('CDN Profile name')
@minLength(1)
@maxLength(260)
param cdnProfileName string

@description('CDN Profile SKU')
param cdnProfileSku object

@description('CDN Endpoint name')
@minLength(1)
@maxLength(50)
param cdnEndpointName string

@description('Location to deploy the resources')
param location string = resourceGroup().location

@description('Log Analytics workspace id to use for diagnostics settings')
param logAnalyticsWorkspaceId string

@description('Web app to confire endpoint for')
param webAppName string

@description('Web app hostname to use in the endpoint')
param webAppHostName string

resource cdnProfile 'Microsoft.Cdn/profiles@2020-09-01' = {
  name: cdnProfileName
  location: location
  sku: cdnProfileSku
}

resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2020-09-01' = {
  parent: cdnProfile
  name: cdnEndpointName
  location: location
  properties: {
    isHttpAllowed: false
    isHttpsAllowed: true
    originHostHeader: webAppHostName
    origins: [
      {
        name: webAppName
        properties: {
          hostName: webAppHostName
          httpPort: 80
          httpsPort: 443
        }
      }
    ]
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
}

resource cdnEndpointDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: cdnEndpoint
  name: 'CDNEndpointDiagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'CoreAnalytics'
        enabled: true
      }
    ]
  }
}

resource cdnProfileDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: cdnProfile
  name: 'CDNProfileDiagnostics'
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
        category: 'AzureCdnAccessLog'
        enabled: true
      }
    ]
  }
}

output cdnEndpointOrigin string = cdnEndpoint.properties.hostName
output cdnEndpointHostName string = cdnEndpoint.properties.originHostHeader
