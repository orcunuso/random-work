# Subject     : Organize Tema Folders
# Prepared by : Ozan Orçunus
# Script Name : FolderOrganize.ps1
# Version     : 1.00

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)][string]$vCenter,
		[Switch]$Test )

function InitializeEnvironment {
	Import-Module -Name INGPSModule -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "FolderOrganize"
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

$VMs = Get-View -ViewType VirtualMachine

foreach ($VM in $VMs) {
	if ($VM.Config.Template) { continue }
	
	$TargetFolderName    = $null
	$VM_Annotation       = $VM.AvailableField | Where-Object { $_.Name -eq "Department" } 
	$VM_Annotation_Key   = $VM_Annotation.Key
	$VM_Annotation_Obj   = $VM.CustomValue | Where-Object { $_.Key -eq $VM_Annotation_Key }
	$VM_Annotation_Value = $VM_Annotation_Obj.Value
	
	$VM_Department = $VM_Annotation_Value
	$VM_GuestOS    = $VM.Config.GuestFullName
	$VM_Site       = "TDA"
	if ($VM_GuestOS.Contains("Windows")) { $VM_OSType = "windowsGuest" }
		else { $VM_OSType = "linuxGuest" }
	
	if ($VM_OSType -eq "windowsGuest") {
		switch ($VM_Department) {
			"Ag Yonetimi"					{ $TargetFolderName = $VM_Site + ".Windows.AgYonetimi"         }
			"Cagri Merkezi Teknolojileri"	{ $TargetFolderName = $VM_Site + ".Windows.CallCenter"         }
			"Guvenlik"						{ $TargetFolderName = $VM_Site + ".Windows.Guvenlik"           }
			"<Not Set>"                     { $TargetFolderName = $Null                                    }
			default							{ $TargetFolderName = $VM_Site + ".Windows.Others"             }
		}
		if (!$VM_Department) { $TargetFolderName = $Null }
	}
		
	if ($VM_OSType -eq "linuxGuest") {
		switch ($VM_Department) {
			"Ag Yonetimi"					{ $TargetFolderName = $VM_Site + ".Linux.AgYonetimi"           }
			"Cagri Merkezi Teknolojileri"	{ $TargetFolderName = $VM_Site + ".Linux.CallCenter"           }
			"Guvenlik"						{ $TargetFolderName = $VM_Site + ".Linux.Guvenlik"             }
			"<Not Set>"                     { $TargetFolderName = $Null                                    }
			default							{ $TargetFolderName = $VM_Site + ".Linux.Others"               }
		}
		if (!$VM_Department) { $TargetFolderName = $Null }
	}
	
	if (!$TargetFolderName) {
		Write-INGLog -Message ("{0}, cannot obtain guest info or null, current folder: {1}" -f $VM.Name, $SourceFolderName) -Color Yellow
		continue
	} else {
		$TargetFolder = Get-View -ViewType Folder -Filter @{"Name" = $TargetFolderName}
	}
	
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


















