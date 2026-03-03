param variables_existingVaultName ? /* TODO: fill in correct type */

@description('Name of the secret to create in the Key Vault.')
param secretName string

@description('Value of the secret. Left empty by default.')
@secure()
param secretValue string

resource variables_existingVaultName_secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${variables_existingVaultName}/${secretName}'
  properties: {
    value: secretValue
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}
