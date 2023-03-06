param parExistingFirewallPolicyName string
param parFirewallPublicIp string 

resource refFirewallPolicy 'Microsoft.Network/firewallPolicies@2022-07-01' existing = {
  name: parExistingFirewallPolicyName
}


// Rule Collection | Solution X
resource resFirewallPolicy 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-07-01' = {
  name: 'name'
  parent: refFirewallPolicy
  properties: {
    priority: 10000
    ruleCollections: [      
      {
        name: 'Deny_Inbound_CatchAll'
        priority: 65000
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'deny'
        }
        rules: [
          {
            description: 'Hub-To-Spoke-Deny-All'
            name: 'Deny-All'
            ruleType: 'NetworkRule'
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '*'
            ]
            ipProtocols: [
              'Any'
            ]
            sourceAddresses: [
              '*'
            ]
          }
        ]
      }
    ]
  }
}

