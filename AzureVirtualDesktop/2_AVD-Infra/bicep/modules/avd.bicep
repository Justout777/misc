param location string 
param hostpoolName string 
param hostpoolNameFriendly string 
param baseTime string = utcNow('u')
param appGroupName string
param workspaceName string


var expirationTime = dateTimeAdd(baseTime, 'P7D')

resource hostpool 'Microsoft.DesktopVirtualization/hostPools@2022-04-01-preview' = {
  name: hostpoolName
  location: location
  properties: {
    friendlyName: hostpoolNameFriendly
    hostPoolType: 'Pooled'
    loadBalancerType: 'BreadthFirst'
    preferredAppGroupType: 'RailApplications'
    validationEnvironment: true
    startVMOnConnect: true
    registrationInfo: {
      expirationTime: expirationTime
      registrationTokenOperation: 'Update'
      token: null
    }
    customRdpProperty: 'drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;redirectwebauthn:i:1;use multimon:i:1;enablerdsaadauth:i:1;autoreconnection enabled:i:1;bandwidthautodetect:i:1;networkautodetect:i:1;compression:i:1;smart sizing:i:1;dynamic resolution:i:1'
  }
}

resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2022-04-01-preview' = {
  name: appGroupName
  location: location
  properties: {
    applicationGroupType:  'RemoteApp'
    hostPoolArmPath: resourceId('Microsoft.DesktopVirtualization/hostpools', hostpoolName)
  }
  dependsOn: [
    hostpool
  ]
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2022-04-01-preview' = {
  name: workspaceName
  location: location
  properties: {
    applicationGroupReferences: [
      appGroup.id
    ]
  }
}
