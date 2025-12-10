targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@secure()
@minLength(8)
@maxLength(123)
@description('Password for VM admin user. Must be 8-123 characters with uppercase, lowercase, number, and special character.')
param VMPassword string

@description('Container registry server (optional - leave empty if image is public)')
param registryServer string = ''

@description('Container registry username (optional)')
param registryUsername string = ''

@secure()
@description('Container registry password (optional)')
param registryPassword string = ''

@description('Address space for the virtual network')
param addressSpace string = '10.34.0.0/16'

@description('Firewall subnet address prefix')
param fwSubnetPrefix string = '10.34.1.0/24'

@description('Monitoring subnet address prefix')
param monSubnetPrefix string = '10.34.2.0/24'

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
  SecurityControl: 'Ignore'
  CostContol: 'Ignore'
}

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module vnetModule 'vnet.bicep' = {
  scope: rg
  params: {
    vnetName: 'vnet-${environmentName}'
    location: location
    tags: tags
    addressSpace: addressSpace
    fwSubnet: {
      name: 'demofwSubnet'
      addressPrefix: fwSubnetPrefix
    }
    monSubnet: {
      name: 'monsubnet'
      addressPrefix: monSubnetPrefix
    }
  }
}

module vmModule 'vm.bicep' = {
  scope: rg
  params: {
    vmName: 'vm-ubuntu-${environmentName}'
    location: location
    tags: tags
    subnetId: vnetModule.outputs.vnet.subnets.monSubnet.id
    adminUsername: 'linadmin'
    adminPassword: VMPassword
  }
}

module aciModule 'aci.bicep' = {
  scope: rg
  params: {
    containerGroupName: 'aci-fwsyslog-${environmentName}'
    location: location
    tags: tags
    subnetId: vnetModule.outputs.vnet.subnets.fwSubnet.id
    serverPrivateIP: vmModule.outputs.vm.privateIP
    containerImage: 'acrdefcontainer.azurecr.io/fwsyslogemulator:latest'
    registryServer: registryServer
    registryUsername: registryUsername
    registryPassword: registryPassword
  }
}

// Outputs
@description('Virtual network information')
output vnet object = vnetModule.outputs.vnet

@description('Virtual machine information')
output vm object = vmModule.outputs.vm

@description('Container group information')
output containerGroup object = aciModule.outputs.containerGroup

