@description('Name of the container group')
param containerGroupName string

@description('Location for the container group')
param location string = resourceGroup().location

@description('Tags to apply to the container group')
param tags object = {}

@description('Subnet ID where the container will be deployed')
param subnetId string

@description('Private IP address of the server (VM)')
param serverPrivateIP string

@description('Container image to deploy')
param containerImage string = 'acrdefcontainer.azurecr.io/fwsyslogemulator:latest'

@description('CPU cores for the container')
param cpuCores int = 1

@description('Memory in GB for the container')
param memoryInGB int = 1

@description('Container registry server (optional)')
param registryServer string = ''

@description('Container registry username (optional)')
param registryUsername string = ''

@secure()
@description('Container registry password (optional)')
param registryPassword string = ''

// Container Group
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerGroupName
  location: location
  tags: tags
  properties: {
    containers: [
      {
        name: 'fwsyslogemulator'
        properties: {
          image: containerImage
          command: [
            'python'
            '/app/simulatesyslog.py'
            '--server'
            serverPrivateIP
          ]
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGB
            }
          }
          environmentVariables: [
            {
              name: 'SERVER_IP'
              value: serverPrivateIP
            }
          ]
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: 'Always'
    ipAddress: {
      type: 'Private'
      ports: [
        {
          port: 514
          protocol: 'UDP'
        }
      ]
    }
    subnetIds: [
      {
        id: subnetId
      }
    ]
    imageRegistryCredentials: !empty(registryServer) ? [
      {
        server: registryServer
        username: registryUsername
        password: registryPassword
      }
    ] : []
  }
}

@description('Container group information')
output containerGroup object = {
  id: containerGroup.id
  name: containerGroup.name
  ipAddress: containerGroup.properties.ipAddress
  provisioningState: containerGroup.properties.provisioningState
}
