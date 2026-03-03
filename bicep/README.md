# Bicep Files

These Bicep files were automatically generated from the ARM template using the Visual Studio Code Bicep extension (Decompile ARM Template).

## Files

- **azuredeploy.bicep** — Main deployment template. Deploys a Consumption Logic App with a system-assigned managed identity, an API connection to Azure Key Vault, and optionally creates a new Key Vault with a secret. Also handles role assignments for Key Vault secret access.
- **nested_addSecretToExistingVault.bicep** — Nested module that adds a secret to an existing Key Vault (used when `createNewKeyVault` is `false`).
- **nested_addRoleAssignmentToExistingVault.bicep** — Nested module that assigns the Key Vault Secrets User role on an existing Key Vault to the Logic App's managed identity.