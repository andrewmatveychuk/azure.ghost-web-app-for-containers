targetScope = 'resourceGroup'

@minLength(2)
@maxLength(64)
param vNetName string
param vNetAddressPrefix string

param privateEndpointsSubnetName string
param privateEndpointsSubnetPrefix string

@description('Location to deploy the resources')
param location string = resourceGroup().location

resource vNet 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: vNetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNetAddressPrefix
      ]
    }
    subnets: [
      {
        name: privateEndpointsSubnetName
        properties: {
          addressPrefix: privateEndpointsSubnetPrefix
        }
      }
    ]
  }
}
