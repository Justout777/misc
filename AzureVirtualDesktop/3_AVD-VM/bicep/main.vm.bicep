// location
param location string = resourceGroup().location

// Unique name for the AVD solution that is used to name all resources. Example: MS-finance-001
param AvdSolutionName string

// network parameters (rg where vnet resides)
param resourcegroupInfra string
param vnetName string
param subnetName string

// number of sessionhosts
param numberVMs int

// login parameters 
@secure()
param adminPassword string
param adminUsername string

// securitygroup ID to assign VM user login role
param securityGroupUser string

// compute gallery parameters
param ComputeGalleryName string
param ComputeGalleryDefName string
param ComputeGalleryRgName string

// hostpool parameters with extension artifact and registration info token
param hostpoolName string
param artifactlocation string // https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_10-27-2022.zip
param registrationInfoToken string
param addHostpool bool = true

// variables
var vmName = 'AVD-VM-${AvdSolutionName}'
var subnetID = resourceId(resourcegroupInfra, 'Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)

// reference resource for gallery image
resource image 'Microsoft.Compute/galleries/images@2022-03-03' existing = {
  name: '${ComputeGalleryName}/${ComputeGalleryDefName}'
  scope: resourceGroup(ComputeGalleryRgName)
}

// receive ID for Virtual Machine User Login
resource virtualMachineUserLoginRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'fb879df8-f326-4884-b1cf-06f3ad86be52'
}

// assign Virtual Machine User Login to security group
resource roleAssignmentStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id)
  properties: {
    roleDefinitionId: virtualMachineUserLoginRole.id
    principalId: securityGroupUser
    principalType:  'Group'
  }
}

// Create networkinterfaces
resource networkInterface 'Microsoft.Network/networkInterfaces@2022-07-01' = [for i in range(0, numberVMs): {
  name: '${vmName}-NIC-${i}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetID
          }
        }
      }
    ]
  }
}]

// create virtual machines
resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-08-01' = [for i in range(0, numberVMs): {
  name: '${vmName}-${i}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    licenseType: 'Windows_Client'
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', '${vmName}-NIC-${i}')
        }
      ]
    }
    osProfile: {
      adminPassword: adminPassword
      adminUsername: adminUsername
      computerName: '${vmName}-${i}'
      windowsConfiguration: {
        enableAutomaticUpdates: false
        patchSettings: {
          patchMode: 'Manual'
        }
      }
    }
    storageProfile: {
      osDisk: {
        name: '${vmName}-OS-${i}'
        createOption: 'FromImage'
        caching: 'ReadOnly'
        deleteOption: 'Delete'
        osType: 'Windows'
      }
    imageReference: {
      id: image.id
    }
    }
  }
  dependsOn: [
    networkInterface[i]
  ]
}]

// add to Azure AD
resource azureADJoin 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = [for i in range(0, numberVMs): {
  name: '${vmName}-${i}/AADLogin'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
  dependsOn: [
    virtualMachine
  ]
}]

// Add to hostpool
resource dscextension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = [for i in range(0, numberVMs): if (addHostpool) {
  name: '${vmName}-${i}/dscextension'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: artifactlocation
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        HostPoolName: hostpoolName
        RegistrationInfoToken: registrationInfoToken
        AadJoin: true
      }
    }
  }
  dependsOn: [
    virtualMachine[i]
    azureADJoin[i]
  ]
}]

// Create apps for specified applicationgroup
module deployapps 'modules/apps.bicep' = {
  name: 'ModuleRemoteApps'
  scope: resourceGroup(resourcegroupInfra)
  params: {
    applicationGroupName: 'AVD-AG-${AvdSolutionName}'
  }
  dependsOn: [
    virtualMachine
  ]
}
