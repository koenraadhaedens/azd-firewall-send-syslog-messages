using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'dev')
param location = readEnvironmentVariable('AZURE_LOCATION', 'eastus')
// VM Password: Set VM_PASSWORD environment variable OR change this default value
// Default password meets Azure requirements but should be changed after deployment
param VMPassword = readEnvironmentVariable('VM_PASSWORD', 'ChangeMe123!')
param registryServer = readEnvironmentVariable('REGISTRY_SERVER', '')
param registryUsername = readEnvironmentVariable('REGISTRY_USERNAME', '')
param registryPassword = readEnvironmentVariable('REGISTRY_PASSWORD', '')
param addressSpace = readEnvironmentVariable('ADDRESS_SPACE', '10.34.0.0/16')
param fwSubnetPrefix = readEnvironmentVariable('FW_SUBNET_PREFIX', '10.34.1.0/24')
param monSubnetPrefix = readEnvironmentVariable('MON_SUBNET_PREFIX', '10.34.2.0/24')
