param location string = resourceGroup().location

// Name of the Compute gallery
param ComputeGalleryName string

// Name of the Compute gallery image definition
param ComputeGalleryDefName string

// gallery image definition properties
param ComputeGalleryDefProp object

// unique name for the userassigned identity
var UaIdentityName = 'uai-${uniqueString(resourceGroup().id)}'

// sets the variables for the custom role
var RoleName = 'Azure Image Builder'
var RoleDescription = 'Provides read and write access to gallery and compute images'
var RoleActions  = [
  'Microsoft.Compute/galleries/read'
  'Microsoft.Compute/galleries/images/read'
  'Microsoft.Compute/galleries/images/versions/read'
  'Microsoft.Compute/galleries/images/versions/write'
  'Microsoft.Compute/images/write'
  'Microsoft.Compute/images/read'
  'Microsoft.Compute/images/delete'
  'Microsoft.ManagedIdentity/userAssignedIdentities/assign/action'
]

var computeGalleryDescription = 'Image Gallery for AVD images'

// Create the user assigned identity
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: UaIdentityName
  location: location
}

// Create the role definition
resource AzureImageBuilderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(RoleName)
  properties: {
    roleName: RoleName
    description: RoleDescription
    type: 'customRole'
    permissions: [
      {
        actions: RoleActions
        notActions: [

        ]
      }
    ]
    assignableScopes: [
      resourceGroup().id
    ]
  }
}

// Assign the custom role to the user-assigned identity
resource roleAssignmentCustomRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id,UaIdentityName)
  properties: {
    roleDefinitionId: AzureImageBuilderRole.id
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Create storageaccount with blob container
module storageaccount 'storageaccountblob/module_storage.bicep' = {
  name: 'storageaccount'
  params: {
    location: location
  }
}

// Receive ID for Blob reader role
resource storageDataBlobReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
}

// assign blob read for the user-assigned identity
resource roleAssignmentStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id,storageaccount.name)
  properties: {
    roleDefinitionId: storageDataBlobReaderRole.id
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// create Compute gallery
resource ComputeGallery 'Microsoft.Compute/galleries@2022-03-03' = {
  name: ComputeGalleryName
  location: location
  properties: {
    description: computeGalleryDescription
    identifier: {}
  }
}

// create image definition
resource imageDefinition 'Microsoft.Compute/galleries/images@2022-03-03' = {
  name: ComputeGalleryDefName
  location: location
  parent: ComputeGallery
  properties: ComputeGalleryDefProp
}
