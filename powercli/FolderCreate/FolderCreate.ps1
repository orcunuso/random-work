# Subject     : Create Team Folders with Permissions
# Prepared by : Ozan Orçunus
# Script Name : FolderCreate.ps1
# Version     : 1.00

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)] [string]$vCenter )

function InitializeEnvironment {
	Import-Module -Name INGPSModule -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "FolderCreate"
	Connect-INGvCenter -vCenter $vCenter
}

function UninitializeEnvironment {
	Disconnect-INGvCenter -vCenter $vCenter
	Uninitialize-INGScript
}

function New-VIGroupPermission {
	param(  [Parameter(Mandatory=$true)][VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]$Folder,
			[Parameter(Mandatory=$true)][string]$Group,
			[Parameter(Mandatory=$true)][VMware.VimAutomation.ViCore.Util10.VersionedObjectImpl]$Role  )

	$MoRef          = $Folder.ExtensionData.MoRef
	$AuthMgr        = Get-View AuthorizationManager
	$Perm           = New-Object VMware.VIM.Permission
	$Perm.Principal = $Group
	$Perm.Group     = $true
	$Perm.Propagate = $true
	$Perm.RoleId    = $Role.ID
	try {
		$AuthMgr.SetEntityPermissions($MoRef,$Perm) | Out-Null
		Write-INGLog -Message ("Permission Added. Entity: {0}, Group: {1}, Role: {2}" -f $Folder.Name, $Group, $Role.Name)
	} catch {
		$ErrorMessage = $_.Exception.Message
		Write-INGLog -Message ("{0}" -f $ErrorMessage) -Color Red
	}
}

function CreateFolder {
	param(  [Parameter(Mandatory=$true)][string]$Name,
			[Parameter(Mandatory=$true)][string]$Location  )
			
	try {
		New-Folder -Name $Name -Location (Get-Folder -Name $Location) | Out-Null
		Write-INGLog -Message ("Folder created: {0}" -f $Name)
	} catch {
		$ErrorMessage = $_.Exception.Message
		Write-INGLog -Message ("{0}" -f $ErrorMessage) -Color Red
	}
}

function CreateAllFolders {
	CreateFolder -Name "TDA.Windows.AgYonetimi" -Location "TDA.FolderGroup.Windows"
	CreateFolder -Name "TDA.Windows.CallCenter" -Location "TDA.FolderGroup.Windows"
	CreateFolder -Name "TDA.Windows.Guvenlik" -Location "TDA.FolderGroup.Windows"
}

function SetFolderPermissions {
	$VRole   = Get-VIRole -Name "VM Administrator" -ErrorAction:SilentlyContinue
	$VRoleOS = Get-VIRole -Name "VM Power Administrator" -ErrorAction:SilentlyContinue
	if ($VRole) {
		New-VIGroupPermission -Folder (Get-Folder -Name TDA.FolderGroup.Windows) -Group "MYDOMAIN\VIClientWindows" -Role $VRoleOS
		New-VIGroupPermission -Folder (Get-Folder -Name TDA.Windows.AgYonetimi) -Group "MYDOMAIN\VIClientNetwork" -Role $VRole
		New-VIGroupPermission -Folder (Get-Folder -Name TDA.Windows.CallCenter) -Group "MYDOMAIN\VIClientCallCenter" -Role $VRole
	} else {
		Write-INGLog -Message ("Role not found") -Color Red
	}
}

function CheckVIRole {
	$VRole = Get-VIRole -Name "VM Administrator" -ErrorAction:SilentlyContinue
	if ($VRole) {
		Write-INGLog -Message ("Virtual Machine Administrator role exists")
	} else {
		Write-INGLog -Message ("Virtual Machine Administrator role does not exist, creating")
		$VIPrivileges = @("","","","","","","","","","")
	}
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

InitializeEnvironment

CreateAllFolders
SetFolderPermissions

UninitializeEnvironment