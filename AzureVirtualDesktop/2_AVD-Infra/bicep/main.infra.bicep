// location
param location string = resourceGroup().location

// Network parameters
param vnetAddressPrefix string
param subnets array

// Unique name for the AVD solution that is used to name all resources. Example: MS-finance-001
param AvdSolutionName string 

// Friendly name for the AVD solution
param AvdFriendlyName string 

// Existing Compute gallery parameters
param imageGalleryName string
param imageDefinitionName string
param installScriptUri string
param resourceGroupImage string
param userAssignedIdentityName string

var subnetProperties = [for subnet in subnets: {
  name: '${subnet.name}'
  properties: {
    addressPrefix: subnet.ipAddressRange
  }
}]

// Create vnet and subnet(s)
resource virtualNetworks 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: 'AVD-VNET-${AvdSolutionName}'
  location: location
  properties:{
    addressSpace:{
      addressPrefixes:[
        vnetAddressPrefix
      ]
    }
    subnets: subnetProperties
  }
}

// Create AVD infra resources
module avdResources 'modules/avd.bicep' = {
  name: 'ModuleAvdResources'
  params: {
    location: location
    hostpoolName: 'AVD-HP-${AvdSolutionName}'
    hostpoolNameFriendly: 'AVD-HP-${AvdFriendlyName}'
    appGroupName: 'AVD-AG-${AvdSolutionName}'
    workspaceName: 'AVD-WS-${AvdSolutionName}'

  }
}

// Create image template
module imageTemplate 'modules/image.bicep' = {
  name: 'ModuleimageTemplate'
  params: {
    imageGalleryName: imageGalleryName
    imageDefinitionName: imageDefinitionName
    installScriptUri: installScriptUri
    location: location
    resourceGroupScopeExisting: resourceGroupImage
    userAssignedIdentityName: userAssignedIdentityName
    vmImageTemplateName: 'AVD-TEMPL-${AvdSolutionName}'
  }
}
