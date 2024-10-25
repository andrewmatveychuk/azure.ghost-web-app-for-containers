targetScope = 'resourceGroup'

@minLength(2)
@maxLength(64)
param virtualNetworkName string



param vnetAddressPrefix string = '10.0.0.0/26'
param webAppSubnetPrefix string = '10.0.0.0/28'
param privateLinksSubnetPrefix string = '10.0.0.16/28'

@description('Location to deploy the resources')
param location string = resourceGroup().location

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'webAppIntegrationSubnet'
        properties: {
          addressPrefix: webAppSubnetPrefix
        }
      }
      {
        name: 'privateLinksSubnet'
        properties: {
          addressPrefix: privateLinksSubnetPrefix
        }
      }
    ]
  }
}
