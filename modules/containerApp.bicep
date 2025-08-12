targetScope = 'resourceGroup'

@minLength(2)
@maxLength(32)
param containerAppName string

param containerAppEnvironmentName string

@description('Location to deploy the resources')
param location string = resourceGroup().location

param minReplicas int = 1
param maxReplicas int = 3

@description('Container image to use')
param containerImageUrl string

@description('Container port')
param containerPort int

@description('Container environment variables')
param containerEnvVars array

@description('Container volume mounts')
param containerVolumeMounts array

@description('List of volume definitions for the Container App')
param containerVolumes array

@description('Collection of secrets used by a Container app')
param containerSecrets array

@description('Container app health probes')
param containerProbes array

param managedIdentityId string

resource containerEnvironment 'Microsoft.App/managedEnvironments@2025-02-02-preview' existing = {
  name: containerAppEnvironmentName
}

resource containerApp 'Microsoft.App/containerApps@2025-02-02-preview' = {
  name: containerAppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: containerPort
        transport: 'http'
        allowInsecure: false
      }
      secrets: containerSecrets
    }
    template: {
      containers: [
        {
          image: containerImageUrl
          name: containerAppName
          env: containerEnvVars
          volumeMounts: containerVolumeMounts
          probes: containerProbes
        }
      ]
      volumes: containerVolumes
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}

output hostName string = containerApp.properties.configuration.ingress.fqdn
