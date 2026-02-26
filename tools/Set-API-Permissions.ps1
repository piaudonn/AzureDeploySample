#Sample script to set a Graph API permission for a Logic App's managed identity. 

#Set the variable with the name of the consumption Logic App.
$LogicAppName = 'DOLA'
Connect-MgGraph -Scopes AppRoleAssignment.ReadWrite.All, Application.Read.All
$Identity = Get-MgServicePrincipal -Filter "displayName eq '$LogicAppName'" #Look for the Identifier of the managed Identity
$GraphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'" #Graph API client ID
$AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq "DeviceManagementServiceConfig.ReadWrite.All" -and $_.AllowedMemberTypes -contains "Application"}
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $Identity.Id -PrincipalId $Identity.Id -ResourceId $GraphServicePrincipal.Id -AppRoleId $AppRole.Id
