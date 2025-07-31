targetScope = 'resourceGroup'

@minLength(2)
@maxLength(64)
param vNetName string
param vNetAddressPrefix string

param integrationSubnetName string
param integrationSubnetPrefix string
param delegatedServiceName string

param privateEndpointsSubnetName string
param privateEndpointsSubnetPrefix string

@description('Location to deploy the resources')
param location string = resourceGroup().location

resource vNet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
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
        name: integrationSubnetName
        properties: {
          addressPrefix: integrationSubnetPrefix
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: delegatedServiceName // 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: privateEndpointsSubnetName
        properties: {
          addressPrefix: privateEndpointsSubnetPrefix
        }
      }
    ]
  }
}
