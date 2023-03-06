
param location string

param vmImageTemplateName string

param userAssignedIdentityName string

param installScriptUri string

param imageDefinitionName string
param imageGalleryName string

param resourceGroupScopeExisting string

// create timestamp
param timestamp string = utcNow()

resource imageDefinition 'Microsoft.Compute/galleries/images@2022-03-03' existing = {
  name: '${imageGalleryName}/${imageDefinitionName}'
  scope: resourceGroup(resourceGroupScopeExisting)
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: userAssignedIdentityName
  scope: resourceGroup(resourceGroupScopeExisting)
}

// Create image Template
resource vmImageTemplate 'Microsoft.VirtualMachineImages/imageTemplates@2022-02-14' = {
  name: vmImageTemplateName
  location: location
  identity:{
    type: 'UserAssigned'
    userAssignedIdentities: {  
      '${userAssignedIdentity.id}': {}
    }
  }
  properties:{
    customize: [
      {
        type: 'PowerShell'
        name: 'CustomInstall'
        runElevated: true
        scriptUri: installScriptUri
      }
      {
        type: 'PowerShell'
        name: 'VDOT'
        inline: [
          'Invoke-WebRequest -Uri https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool/blob/main/Windows_VDOT.ps1 -OutFile .\\Windows_VDOT.ps1; .\\Windows_VDOT.ps1 -Optimizations All -Verbose -AcceptEula'
        ]
        runElevated: true
      }
      {
        type: 'WindowsRestart'
        restartCommand: 'shutdown /r /f /t 0'
        restartTimeout: '5m'
      }
      {
        type: 'WindowsUpdate'
        filters: [
          'exclude:$_.Title -like "*Preview*"'
          'include:$true'
        ]
        updateLimit: 40
      }
      {
        type: 'WindowsRestart'
        restartCommand: 'shutdown /r /f /t 0'
        restartTimeout: '5m'
      }
    ]
    distribute: [
      {
        type: 'SharedImage'
        galleryImageId: imageDefinition.id
        runOutputName: timestamp 
        replicationRegions: [
          location
        ]
      }
    ]
    source: {
      type: 'PlatformImage'
      publisher: 'MicrosoftWindowsDesktop'
      offer: 'windows-10'
      sku: 'win10-22h2-avd'
      version: 'latest'
    }
    vmProfile:{
      userAssignedIdentities: [
        userAssignedIdentity.id
      ]
    }
  }
}
