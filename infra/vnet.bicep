@description('Name of the virtual network')
param vnetName string

@description('Location for the virtual network')
param location string = resourceGroup().location

@description('Tags to apply to the virtual network')
param tags object = {}

@description('Address space for the virtual network')
param addressSpace string = '10.34.0.0/16'

@description('Firewall subnet configuration')
param fwSubnet object = {
  name: 'fwSubnet'
  addressPrefix: '10.34.1.0/24'
}

@description('Monitoring subnet configuration')
param monSubnet object = {
  name: 'monsubnet'
  addressPrefix: '10.34.2.0/24'
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpace
      ]
    }
    subnets: [
      {
        name: fwSubnet.name
        properties: {
          addressPrefix: fwSubnet.addressPrefix
        }
      }
      {
        name: monSubnet.name
        properties: {
          addressPrefix: monSubnet.addressPrefix
        }
      }
    ]
  }
}

@description('Virtual network resource')
output vnet object = {
  id: vnet.id
  name: vnet.name
  addressSpace: vnet.properties.addressSpace.addressPrefixes[0]
  subnets: {
    fwSubnet: {
      id: vnet.properties.subnets[0].id
      name: vnet.properties.subnets[0].name
      addressPrefix: vnet.properties.subnets[0].properties.addressPrefix
    }
    monSubnet: {
      id: vnet.properties.subnets[1].id
      name: vnet.properties.subnets[1].name
      addressPrefix: vnet.properties.subnets[1].properties.addressPrefix
    }
  }
}
