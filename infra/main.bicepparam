using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'dev')
param location = readEnvironmentVariable('AZURE_LOCATION', 'eastus')
// Remove the line below to be prompted for VM password. 
// When this parameter is removed, azd will prompt for VMPassword as it's marked @secure() in main.bicep
param VMPassword = readEnvironmentVariable('VM_PASSWORD', 'REMOVE_THIS_LINE_TO_PROMPT_FOR_PASSWORD')
param registryServer = readEnvironmentVariable('REGISTRY_SERVER', '')
param registryUsername = readEnvironmentVariable('REGISTRY_USERNAME', '')
param registryPassword = readEnvironmentVariable('REGISTRY_PASSWORD', '')
param addressSpace = readEnvironmentVariable('ADDRESS_SPACE', '10.34.0.0/16')
param fwSubnetPrefix = readEnvironmentVariable('FW_SUBNET_PREFIX', '10.34.1.0/24')
param monSubnetPrefix = readEnvironmentVariable('MON_SUBNET_PREFIX', '10.34.2.0/24')
