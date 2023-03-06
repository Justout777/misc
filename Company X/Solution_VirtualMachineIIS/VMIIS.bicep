param location string = 'westeurope'

// params from hub network
param RghubName string 
param parSubscriptionHUbNetworkingId string 
param parHubVirtualNetworkName string 
param parNextHopIpAddress string 

// param for spoke network
param newDeployment bool = false // I use this because of the 'issue' with vnets that remove their subnets when not defined in the same resource during a re-deployment
param parSpokeNetworkName string 
param parSpokeNetworkAddressPrefix string 
param parSubnets array 

// params for VM
param diagnosticWorkspaceId string 
param adminUsername string 
@secure()
param adminPassword string 

resource hubNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: parHubVirtualNetworkName
  scope: resourceGroup(parSubscriptionHUbNetworkingId, RghubName)
}

module resSpokeNetwork '../Modules/ALZ/modules/spokeNetworking/spokeNetworking.bicep' = if(newDeployment) {
  name: 'DeploySpokeNetwork'
  params: {
    parSpokeNetworkName: parSpokeNetworkName
    parLocation: location
    parSpokeNetworkAddressPrefix: parSpokeNetworkAddressPrefix
    parNextHopIpAddress: parNextHopIpAddress
  }
}

resource refSpokeNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: parSpokeNetworkName
}

@batchSize(1)
resource resSpokeNetworkSub 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = [for (i, index) in parSubnets: {
  name: i.name
  parent: refSpokeNetwork
  properties: {
    addressPrefix: i.ipAddressRange
    routeTable: {
      id: resSpokeNetwork.outputs.outSpokeRouteTableId
    }
      }
  dependsOn: [
    resSpokeNetwork
  ]
}]

module resPeerSpokeToHub '../Modules/ALZ/modules/vnetPeering/vnetPeering.bicep' = {
  name: 'peerSpokeToHub'
  params: {
    parDestinationVirtualNetworkId: hubNetwork.id
    parDestinationVirtualNetworkName: hubNetwork.name
    parSourceVirtualNetworkName: resSpokeNetwork.outputs.outSpokeVirtualNetworkName
  }
  dependsOn: [
    resSpokeNetwork
  ]
}

module resPeerHubToSpoke '../Modules/ALZ/modules/vnetPeering/vnetPeering.bicep' = {
  scope: resourceGroup(parSubscriptionHUbNetworkingId, RghubName)
  name: 'peerHubToSpoke'
  params: {
    parDestinationVirtualNetworkId: resSpokeNetwork.outputs.outSpokeVirtualNetworkId
    parDestinationVirtualNetworkName: resSpokeNetwork.outputs.outSpokeVirtualNetworkName
    parSourceVirtualNetworkName: hubNetwork.name
  }
  dependsOn: [
    resSpokeNetwork
  ]
}

module resVMIIS '../Modules/ResourceModules/Microsoft.Compute/virtualMachines/deploy.bicep' = {
  name: 'deployVirtualMachine'
  params: {
    name: 'VM'
    location: location
    adminUsername: adminUsername
    adminPassword: adminPassword
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
    nicConfigurations: [
        {
          nicSuffix: '-nic-01'
          ipConfigurations: [
            {
              name: 'ipconfig1'
              subnetResourceId: resSpokeNetworkSub[0].id
            }
          ]
        }
      ]
    osDisk: {
      createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      diskSizeGB: 127        
    }
    osType: 'Windows'
    vmSize: 'Standard_D2s_v4'
    systemAssignedIdentity: true
    diagnosticWorkspaceId: diagnosticWorkspaceId
  }
}
