targetScope = 'managementGroup'

param location string

// root management group
param parTopLevelManagementGroupPrefix string 

// params for logging
param parSubscriptionLoggingId string 
param parResourceGroupLogging string  
param parLogAnalyticsWorkspaceName string 

// params for hub network
param parSubscriptionHUbNetworkingId string
param parResourceGroupHub string 
param parCompanyPrefix string 

module managementGroups '../Modules/ALZ/modules/managementGroups/managementGroups.bicep' = {
  scope: tenant()
  name: '1_ManagementGroups'
  params: {
    parTopLevelManagementGroupPrefix: parTopLevelManagementGroupPrefix
    parLandingZoneMgAlzDefaultsEnable: false
  }
}

module policyDefinitions '../Modules/ALZ/modules/policy/definitions/customPolicyDefinitions.bicep' = {
  name: '2_PolicyDefinitions'
  scope: managementGroup(parTopLevelManagementGroupPrefix)
  params: {
    parTargetManagementGroupId: parTopLevelManagementGroupPrefix
  }
  dependsOn: [
    managementGroups
  ]
}

module customRoleDefinitions '../Modules/ALZ/modules/customRoleDefinitions/customRoleDefinitions.bicep' = {
  name: '3_CustomRoleDefinitions'
  scope: managementGroup(parTopLevelManagementGroupPrefix)
  params: {
    parAssignableScopeManagementGroupId: parTopLevelManagementGroupPrefix
  }
  dependsOn: [
    policyDefinitions
  ]
}

module resourceGroupLogging '../Modules/ALZ/modules/resourceGroup/resourceGroup.bicep' = {
  scope: subscription(parSubscriptionLoggingId)
  name: '4_ResourcegroupLogging'
  params: {
    parLocation: location
    parResourceGroupName: parResourceGroupLogging
  }
  dependsOn: [
    customRoleDefinitions
  ]
}

module logging '../Modules/ALZ/modules/logging/logging.bicep' = {
  scope: resourceGroup(parSubscriptionLoggingId, parResourceGroupLogging)
  name: '4_LoggingResources'
  params: {
    parLogAnalyticsWorkspaceLocation: location
    parAutomationAccountLocation: location
    parLogAnalyticsWorkspaceName: parLogAnalyticsWorkspaceName
  }
  dependsOn: [
    resourceGroupLogging
  ]
}

module mgDiag '../Modules/ALZ/modules/mgDiagSettings/mgDiagSettings.bicep' = {
  name: '4.1_mGDiagSettings'
  params: {
    parLogAnalyticsWorkspaceResourceId: logging.outputs.outLogAnalyticsWorkspaceId
  }
  dependsOn: [
    logging
  ]
}

module resourceGroupHubNetworking '../Modules/ALZ/modules/resourceGroup/resourceGroup.bicep' = {
  scope: subscription(parSubscriptionHUbNetworkingId)
  name: '5_ResourcegroupHubNetworking'
  params: {
    parLocation: location
    parResourceGroupName: parResourceGroupHub
  }
  dependsOn: [
    mgDiag
  ]
}

module hubvnet '../Modules/ALZ/modules/hubNetworking/hubNetworking.bicep' = {
  scope: resourceGroup(parSubscriptionHUbNetworkingId ,parResourceGroupHub)
  name: '5_HubNetwork'
  params: {
    parLocation: location
    parAzBastionEnabled: false
    parDdosEnabled: false
    parVpnGatewayConfig: {}
    parCompanyPrefix: parCompanyPrefix
    parFirewallPolicyInsightsEnable: true
    parFirewallPolicyWorkspaceId: logging.outputs.outLogAnalyticsWorkspaceId
  }
  dependsOn: [
    resourceGroupHubNetworking
  ]
}

module policyAssignments '../Modules/ALZ/modules/policy/assignments/alzDefaults/alzDefaultPolicyAssignments.bicep' = {
  name: '8_policyAssignments'
  params: {
    parTopLevelManagementGroupPrefix: parTopLevelManagementGroupPrefix
    parDisableAlzDefaultPolicies: false
    parLogAnalyticsWorkSpaceAndAutomationAccountLocation: location
    parLogAnalyticsWorkspaceResourceId: logging.outputs.outLogAnalyticsWorkspaceId
    parAutomationAccountName: logging.outputs.outAutomationAccountName
    parDdosProtectionPlanId: ''
  }
}
