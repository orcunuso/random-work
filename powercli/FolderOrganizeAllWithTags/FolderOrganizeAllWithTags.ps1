# Subject     : Organize Tema Folders
# Prepared by : Ozan Orçunus
# Script Name : FolderOrganize.ps1
# Version     : 1.00

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)][string]$vCenter,
		[Parameter(Mandatory=$true)][string]$SiteCode,
		[Switch]$Test )

function InitializeEnvironment {
	Import-Module -Name INGPSModule -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "FolderOrganizeAllWithTags"
	Connect-INGvCenter -vCenter $vCenter
}

function UninitializeEnvironment {
	Disconnect-INGvCenter -vCenter $vCenter
	Uninitialize-INGScript
}

function Get-FolderFromVM {
	param ( [Parameter(Mandatory=$true)][String]$VMName)
	
	$VM = Get-View -ViewType VirtualMachine -Filter @{"Name" = $VMName} -ErrorAction SilentlyContinue
	$Parent = $VM.Parent
	if ($Parent.Type -eq "Folder") {
		$FolderID = ("{0}-{1}" -f $Parent.Type, $Parent.Value)
		$Folder = Get-Folder -Id $FolderID
		return $Folder.Name
	}
	
	return $null
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

InitializeEnvironment

$VMs = Get-VM

foreach ($VM in $VMs) {
	if ($VM.ExtensionData.Config.Template) { continue }
	
	$TargetFolderName    = $null
	$VM_Department       = $null
	$VM_Department       = Get-TagAssignment -Category Department -Entity $VM
	$VM_GuestOS          = $VM.ExtensionData.Config.GuestFullName
	$VM_Site             = $SiteCode
	if ($VM_GuestOS.Contains("Windows")) { $VM_OSType = "Windows" }
		else { $VM_OSType = "Linux" }
	
	switch ($VM_Department) {
		"Dep_Application"	{ $TargetFolderName = $VM_Site + "." + $VM_OSType + ".Application"	}
		"Dep_CallCenter"	{ $TargetFolderName = $VM_Site + "." + $VM_OSType + ".CallCenter"	}	
		default				{ $TargetFolderName = $VM_Site + "." + $VM_OSType + ".Others"		}
	}	
	
	$TargetFolder     = Get-View -ViewType Folder -Filter @{"Name" = $TargetFolderName}
	$SourceFolderName = Get-FolderFromVM -VMName $VM.Name
	$SourceFolder     = Get-View -ViewType Folder -Filter @{"Name" = $SourceFolderName}
	
	if ($SourceFolder.Name -eq $TargetFolder.Name) {
		Write-INGLog -Message ("{0} is already in correct folder: {1}" -f $VM.Name, $SourceFolder.Name)
		continue
	}
	
	try {
		if ($Test) { 
			Write-INGLog -Message ("TEST: {0} has been moved to {1}" -f $VM.Name, $TargetFolder.Name) -Color Cyan
		} else {
			$TargetFolder.MoveIntoFolder($VM.MoRef)
			Write-INGLog -Message ("{0} has been moved to {1}" -f $VM.Name, $TargetFolder.Name) -Color Cyan
		}
	} catch {
		$ErrorMessage = $_.Exception.Message
		Write-INGLog -Message ("{1}: {0}" -f $ErrorMessage, $VM.Name) -Color Red
	}
}

UninitializeEnvironment


















