# This script is just a sample which generates a Shared Access Signature (SAS) token for Azure Service Bus.
# This is taken from https://medium.com/@lubs_D/generating-a-shared-access-signature-sas-token-for-azure-service-bus-in-powershell-89775e0bf071

# Load the required assembly for System.Web
[Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null

# Configure the Azure Service Bus namespace, access policy, and key
$Namespace = "myNamespace.servicebus.windows.net"
$AccessPolicyName = "RootManageSharedAccessKey"
$AccessPolicyKey = "myPrimaryKey"

# Define the token expiration time (in seconds) - Modify as needed
# For example, to set the token to expire in one year, replace 300 with 31536000 (365 days)
$Expires = ([DateTimeOffset]::Now.ToUnixTimeSeconds()) + 300

# Create the signature string
$SignatureString = [System.Web.HttpUtility]::UrlEncode($Namespace) + "`n" + [string]$Expires

# Create an HMACSHA256 object and set the key
$HMAC = New-Object System.Security.Cryptography.HMACSHA256
$HMAC.Key = [Text.Encoding]::ASCII.GetBytes($AccessPolicyKey)

# Compute the signature
$Signature = $HMAC.ComputeHash([Text.Encoding]::ASCII.GetBytes($SignatureString))
$Signature = [Convert]::ToBase64String($Signature)

# Build the SAS token
$SASToken = "SharedAccessSignature sr=" + [System.Web.HttpUtility]::UrlEncode($Namespace) + "&sig=" + [System.Web.HttpUtility]::UrlEncode($Signature) + "&se=" + $Expires + "&skn=" + $AccessPolicyName

# Output the generated SAS token
$SASToken