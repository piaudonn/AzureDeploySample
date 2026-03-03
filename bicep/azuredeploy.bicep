@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the Consumption Logic App.')
param logicAppName string

@description('Initial state of the Logic App.')
@allowed([
  'Enabled'
  'Disabled'
])
param logicAppState string = 'Enabled'

@description('If true, deploy a new Key Vault. If false, use an existing one.')
param createNewKeyVault bool = true

@description('Name of the new Key Vault (required when createNewKeyVault is true).')
param newKeyVaultName string = ''

@description('SKU for the new Key Vault.')
@allowed([
  'standard'
  'premium'
])
param newKeyVaultSku string = 'standard'

@description('Full resource ID of an existing Key Vault (required when createNewKeyVault is false).')
param existingKeyVaultId string = ''

@description('Name of the secret to create in the Key Vault.')
param secretName string = 'BusSignature'

@description('Value of the secret. Left empty by default.')
@secure()
param secretValue string = ''

@description('URL of the Service Bus queue.')
param serviceBusQueueUrl string = ''

@description('If true, grant the Logic App managed identity the Key Vault Secrets User role on the effective Key Vault.')
param grantServiceBusKeyPermissions bool = false

var existingVaultSubscription = (createNewKeyVault ? subscription().subscriptionId : split(existingKeyVaultId, '/')[2])
var existingVaultResourceGroup = (createNewKeyVault ? resourceGroup().name : split(existingKeyVaultId, '/')[4])
var existingVaultName = (createNewKeyVault ? 'none' : last(split(existingKeyVaultId, '/')))
var effectiveVaultName = (createNewKeyVault ? newKeyVaultName : existingVaultName)

resource effectiveVault 'Microsoft.Web/connections@2016-06-01' = {
  name: effectiveVaultName
  location: location
  kind: 'V1'
  properties: {
    displayName: 'SMI-KeyVault'
    parameterValueType: 'Alternative'
    api: {
      name: effectiveVaultName
      displayName: 'Azure Key Vault'
      description: 'Azure Key Vault is a service to securely store and access secrets.'
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/keyvault'
      type: 'Microsoft.Web/locations/managedApis'
    }
    testLinks: []
  }
}

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: logicAppState
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        ServiceBusName: {
          defaultValue: first(split(split(serviceBusQueueUrl, '/')[2], '.'))
          type: 'String'
        }
        ServiceBusQueueName: {
          defaultValue: last(split(serviceBusQueueUrl, '/'))
          type: 'String'
        }
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        Every_5_minutes: {
          recurrence: {
            interval: 5
            frequency: 'Minute'
          }
          evaluatedRecurrence: {
            interval: 5
            frequency: 'Minute'
          }
          type: 'Recurrence'
        }
      }
      actions: {
        HTTP_call_to_a_service_bus_with_SAS: {
          runAfter: {
            Get_SAS: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            uri: 'https://@{parameters(\'ServiceBusName\')}.servicebus.windows.net:443/@{parameters(\'ServiceBusQueueName\')}/messages/head'
            method: 'POST'
            authentication: {
              type: 'Raw'
              value: 'SharedAccessSignature @{body(\'Get_SAS\')?[\'value\']}'
            }
          }
          runtimeConfiguration: {
            contentTransfer: {
              transferMode: 'Chunked'
            }
          }
        }
        Get_SAS: {
          runAfter: {}
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'keyvault\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/secrets/@{encodeURIComponent(\'BusSignature\')}/value'
          }
          runtimeConfiguration: {
            secureData: {
              properties: [
                'inputs'
                'outputs'
              ]
            }
          }
        }
        HTTP_call_to_the_Graph_API_with_Managed_Identity: {
          runAfter: {
            HTTP_call_to_a_service_bus_with_SAS: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            uri: 'https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities'
            method: 'GET'
            authentication: {
              type: 'ManagedServiceIdentity'
              audience: 'https://graph.microsoft.com/'
            }
          }
          runtimeConfiguration: {
            contentTransfer: {
              transferMode: 'Chunked'
            }
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          keyvault: {
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/keyvault'
            connectionId: effectiveVault.id
            connectionName: effectiveVaultName
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
          }
        }
      }
    }
  }
}

resource createNewKeyVault_newKeyVaultName_placeholder 'Microsoft.KeyVault/vaults@2023-07-01' = if (createNewKeyVault) {
  name: (createNewKeyVault ? newKeyVaultName : 'placeholder')
  location: location
  properties: {
    sku: {
      family: 'A'
      name: newKeyVaultSku
    }
    tenantId: subscription().tenantId
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: true
    accessPolicies: []
  }
}

resource createNewKeyVault_newKeyVaultName_placeholder_secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (createNewKeyVault) {
  name: '${(createNewKeyVault?newKeyVaultName:'placeholder')}/${secretName}'
  properties: {
    value: secretValue
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
  dependsOn: [
    createNewKeyVault_newKeyVaultName_placeholder
  ]
}

module addSecretToExistingVault './nested_addSecretToExistingVault.bicep' = if (!createNewKeyVault) {
  name: 'addSecretToExistingVault'
  scope: resourceGroup(existingVaultSubscription, existingVaultResourceGroup)
  params: {
    variables_existingVaultName: existingVaultName
    secretName: secretName
    secretValue: secretValue
  }
}

resource Microsoft_KeyVault_vaults_createNewKeyVault_newKeyVaultName_placeholder_logicAppName_4633458b_17de_408a_b874_0445c86b69e6 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (grantServiceBusKeyPermissions && createNewKeyVault) {
  scope: createNewKeyVault_newKeyVaultName_placeholder
  name: guid(createNewKeyVault_newKeyVaultName_placeholder.id, logicAppName, '4633458b-17de-408a-b874-0445c86b69e6')
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'
    )
    principalId: reference(logicApp.id, '2019-05-01', 'full').identity.principalId
    principalType: 'ServicePrincipal'
  }
}

module addRoleAssignmentToExistingVault './nested_addRoleAssignmentToExistingVault.bicep' = if (grantServiceBusKeyPermissions && (!createNewKeyVault)) {
  name: 'addRoleAssignmentToExistingVault'
  scope: resourceGroup(existingVaultSubscription, existingVaultResourceGroup)
  params: {
    resourceId_Microsoft_Logic_workflows_parameters_logicAppName: reference(logicApp.id, '2019-05-01', 'full')
    variables_existingVaultName: existingVaultName
    existingKeyVaultId: existingKeyVaultId
    logicAppName: logicAppName
  }
}

output logicAppId string = logicApp.id
output keyVaultName string = effectiveVaultName
output secretUri string = (createNewKeyVault
  ? reference(resourceId('Microsoft.KeyVault/vaults/secrets', newKeyVaultName, secretName), '2023-07-01').secretUri
  : 'See nested deployment output')
