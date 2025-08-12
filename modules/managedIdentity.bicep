targetScope = 'resourceGroup'

@description('User-defined name for the managed identity')
@minLength(4)
@maxLength(63)
param managedIdentityName string

@description('Location to deploy the resources')
param location string = resourceGroup().location

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: managedIdentityName
  location: location
}

output id string = managedIdentity.id
output principalId string = managedIdentity.properties.principalId
output principalName string = managedIdentity.name
