param parLocation string = resourceGroup().location

@allowed([
  'prd'
  'tst'
])
param parEnvironment string 
param parSolutionPrefix string = 'webapp001'

// params for network
param parVnetAddressPrefix string 
param parNumberofPIPs int 
param parSubnets array = [
    {
    name: 'ApplicationGateway'
    ipAddressRange: '10.10.250.0/26'
    nsgName: ''
    }
    {
    name: 'AzureBastionSubnet'
    ipAddressRange: '10.10.240.0/24'
    nsgName: 'nsg-${parSolutionPrefix}-bastion-${parLocation}-${parEnvironment}'
    }
    {
    name: 'sub-${parSolutionPrefix}-web'
    ipAddressRange: '10.10.10.0/24'
    nsgName: 'nsg-${parSolutionPrefix}-web-${parLocation}-${parEnvironment}'
    }
    {
    name: 'sub-${parSolutionPrefix}-data'
    ipAddressRange: '10.10.15.0/24'
    nsgName: 'nsg-${parSolutionPrefix}-data-${parLocation}-${parEnvironment}'
    }
]

// params for virtual machine scale set
param parNumberOfInstances int = 3
param parVmSku string = 'Standard_b2ms'
param parWindowsOsVersion string = '2022-Datacenter'
param parUsername string 
@secure()
param parPassword string 

// variables
var varSqlMiName = 'sqlmi-${parSolutionPrefix}-${parLocation}-${parEnvironment}'
var varAppGatewayName = 'apg-${parSolutionPrefix}-${parLocation}-${parEnvironment}'
var varBackendPoolName = 'bep-${parSolutionPrefix}-${parLocation}-${parEnvironment}'
var varVmssName = 'vmss-${parSolutionPrefix}-${parLocation}-${parEnvironment}'
var varNicName = 'nic-${parSolutionPrefix}'
var varInstanceName = 'vmssi'
var varRouteTable = 'rt-${parSolutionPrefix}-data'
var varVnetName = 'vnet-${parSolutionPrefix}-${parLocation}-${parEnvironment}'
var varPipName = 'pip-${parSolutionPrefix}-${parLocation}-${parEnvironment}'
var varNsgWebName = 'nsg-${parSolutionPrefix}-web-${parLocation}-${parEnvironment}'
var varNsgDataName = 'nsg-${parSolutionPrefix}-data-${parLocation}-${parEnvironment}'
var varNsgBastionName = 'nsg-${parSolutionPrefix}-bastion-${parLocation}-${parEnvironment}'
var varImageReference = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: parWindowsOsVersion
  version: 'latest'
}

// deploy network resource
resource resNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: varVnetName
  location: parLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        parVnetAddressPrefix
      ]
    }
    subnets: [for i in parSubnets: {
      name: i.name
      properties: {
        addressPrefix: i.ipAddressRange
        networkSecurityGroup: i.name == 'ApplicationGateway' ? null : {
          id: '${resourceGroup().id}/providers/Microsoft.Network/networkSecurityGroups/${i.nsgName}'
        }
        delegations: i.name != 'sub-${parSolutionPrefix}-data' ? null : [
          {
            name: 'managedInstanceDelegation'
            properties: {
              serviceName: 'Microsoft.Sql/managedInstances'
            }
          }
        ]
        routeTable: i.name != 'sub-${parSolutionPrefix}-data' ? null : {
          id: resRouteTable.id
        }
      }
    }]
  }
  dependsOn: [
    resBastionNsg
    resDataNsg
    resWebNsg
  ]
}

// deploy PIP
resource resPublicIP 'Microsoft.Network/publicIPAddresses@2022-01-01' = [for i in range(0,parNumberofPIPs): {
  name: '${varPipName}-${i}'
  location: parLocation
  sku: {
   name: 'Standard' 
  }
  properties: {
   publicIPAddressVersion: 'IPv4'
   publicIPAllocationMethod: 'Static' 
  }
}]

// deploy virtual machine scale set
resource resVMSS 'Microsoft.Compute/virtualMachineScaleSets@2022-11-01' = {
  name: varVmssName
  location: parLocation
  sku: {
    name: parVmSku
    tier: 'Standard'
    capacity: parNumberOfInstances
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    overprovision: true
    upgradePolicy: {
      mode: 'Automatic'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          caching: 'ReadWrite'
          createOption: 'FromImage'
        }
        imageReference: varImageReference
      }
      osProfile: {
        computerNamePrefix: varInstanceName
        adminUsername: parUsername
        adminPassword: parPassword
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: varNicName
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: resourceId('Microsoft.Network/virtualNetworks/subnets', varVnetName, 'sub-${parSolutionPrefix}-web')
                    }
                    applicationGatewayBackendAddressPools: [
                      {
                        id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', varAppGatewayName, varBackendPoolName)
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'installIIS'
            properties: {
              autoUpgradeMinorVersion: true
              publisher: 'Microsoft.Compute'
              type: 'CustomScriptExtension'
              typeHandlerVersion: '1.4'
              settings: {
                commandToExecute: 'powershell Add-WindowsFeature Web-Server'
              }
            }
          }
        ]
      }    
    }
  }
  dependsOn: [
    resApplicationGateWay
  ]
}

resource resApplicationGateWay 'Microsoft.Network/applicationGateways@2021-05-01' = {
  name: varAppGatewayName
  location: parLocation
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', varVnetName, 'ApplicationGateway')
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', resPublicIP[0].name)
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: varBackendPoolName
        properties: {}
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'myHTTPSetting'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: false
          requestTimeout: 20
        }
      }
    ]
    httpListeners: [
      {
        name: 'myListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', varAppGatewayName, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', varAppGatewayName , 'port_80')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'myRoutingRule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', varAppGatewayName, 'myListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', varAppGatewayName, varBackendPoolName)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', varAppGatewayName, 'myHTTPSetting')
          }
        }
      }
    ]
    enableHttp2: false
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 10
    }
  }
  dependsOn: [
    resNetwork
    resPublicIP
  ]
}

resource resRouteTable 'Microsoft.Network/routeTables@2021-08-01' = {
  name: varRouteTable
  location: parLocation
  properties: {
    disableBgpRoutePropagation: false
  }
}

resource resSqlMi 'Microsoft.Sql/managedInstances@2021-11-01' = {
  name: varSqlMiName
  location: parLocation
  sku: {
    name: 'GP_Gen5'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: parUsername
    administratorLoginPassword: parPassword
    subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', varVnetName, 'sub-${parSolutionPrefix}-data')
    storageSizeInGB: 256
    vCores: 8
    licenseType: 'BasePrice'
    zoneRedundant: true
  }
  dependsOn: [
    resNetwork
  ]
}

resource resWebNsg 'Microsoft.Network/networkSecurityGroups@2021-08-01' = {
  name: varNsgWebName
  location: parLocation
  properties: {
    securityRules: [
      // inbound rules
      {
        name: 'AllowGatewayManagerInbound'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
        }
      }
      // outbound rules
      {
        name: 'AllowHttpsOutbound'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 1000
          sourceAddressPrefix: '10.10.10.0/24'
          destinationAddressPrefix: 'Internet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowOutboundSqlRedirect'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 1100
          sourceAddressPrefix: '10.10.10.0/24'
          destinationAddressPrefix: '10.10.15.0/24'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '11000-11999'
        }
      }
      {
        name: 'AllowOutboundSqlTds'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 1150
          sourceAddressPrefix: '10.10.10.0/24'
          destinationAddressPrefix: '10.10.15.0/24'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
        }
      }
    ]
  }
}

resource resDataNsg 'Microsoft.Network/networkSecurityGroups@2021-08-01' = {
  name: varNsgDataName
  location: parLocation
  properties: {
    securityRules: [
       // inbound rules
       {
        name: 'AllowInboundSqlRedirect'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          sourceAddressPrefix: '10.10.10.0/24'
          destinationAddressPrefix: '10.10.15.0/24'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '11000-11999'
        }
      }
      {
        name: 'AllowInboundSqlTds'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 150
          sourceAddressPrefix: '10.10.10.0/24'
          destinationAddressPrefix: '10.10.15.0/24'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
        }
      }
      // outbound rules
      {
        name: 'AllowOutboundHttps'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 1000
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

resource resBastionNsg 'Microsoft.Network/networkSecurityGroups@2021-08-01' = {
  name: varNsgBastionName
  location: parLocation
  properties: {
    securityRules: [
      // Inbound Rules
      {
        name: 'AllowInboundHttps'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowInboundGatewayManager'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 150
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowInboundAzureLoadBalancer'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 200
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowInboundBastionHostCommunication'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 250
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
        }
      }
      // Outbound Rules
      {
        name: 'AllowOutboundSshRDP'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 1000
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
        }
      }
      {
        name: 'AllowOutboundAzureCloud'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 1100
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowOutboundBastionCommunication'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 1150
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
        }
      }
      {
        name: 'AllowOutboundGetSessionInformation'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 1200
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}


