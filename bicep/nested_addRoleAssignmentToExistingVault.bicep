param resourceId_Microsoft_Logic_workflows_parameters_logicAppName object
param variables_existingVaultName ? /* TODO: fill in correct type */

@description('Full resource ID of an existing Key Vault (required when createNewKeyVault is false).')
param existingKeyVaultId string

@description('Name of the Consumption Logic App.')
param logicAppName string

resource existingKeyVaultId_logicAppName_4633458b_17de_408a_b874_0445c86b69e6 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: 'Microsoft.KeyVault/vaults/${variables_existingVaultName}'
  name: guid(existingKeyVaultId, logicAppName, '4633458b-17de-408a-b874-0445c86b69e6')
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'
    )
    principalId: resourceId_Microsoft_Logic_workflows_parameters_logicAppName.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
