// this template contains all the applications that are placed in the given applicationgroup

param applicationGroupName string

resource applicationgroup 'Microsoft.DesktopVirtualization/applicationGroups@2022-04-01-preview' existing = {
  name: applicationGroupName
}

param adobeReaderAcrobatDCName string = 'adobeReaderAcrobatDCName'
resource AdobeReader 'Microsoft.DesktopVirtualization/applicationGroups/applications@2022-04-01-preview' = {
  name: adobeReaderAcrobatDCName
  parent: applicationgroup
  properties: {
    applicationType: 'InBuilt'
    commandLineSetting: 'Allow'
    description: 'Adobe Reader Acrobat DC'
    filePath: 'C:\\Program Files (x86)\\Adobe\\Acrobat Reader DC\\Reader\\AcroRd32.exe'
    showInPortal: true
  }
}

param studiocodeName string = 'VisualStudioCode'
resource StudioCode 'Microsoft.DesktopVirtualization/applicationGroups/applications@2022-04-01-preview' = {
  name: studiocodeName
  parent: applicationgroup
  properties: {
    applicationType: 'InBuilt'
    commandLineSetting: 'Allow'
    description: 'Visual Studio Code'
    filePath: 'C:\\Program Files\\Microsoft VS Code\\Code.exe'
    showInPortal: true
  }
}
