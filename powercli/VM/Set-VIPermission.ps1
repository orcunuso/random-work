#Get-Module -ListAvailable
#Import-Module viToolkitExtensions -PassThru

$VIObject = Get-Folder -Name "Datacenters"

$MyPermission = New-Object VMware.Vim.Permission
$MyPermission.principal = "MYDOMAIN\svc"
$MyPermission.group = $false
$myPermission.propagate = $true
$MyPermission.RoleId = (Get-TkeRoles | Where-Object {$_.Name -eq "NetApp VSC Optimization"} | % {$_.RoleId})
Set-TkePermissions $VIObject $MyPermission