# Project     : BackupControllerDisable
# Prepared by : Ozan Orçunus
#

# [FUNCTIONS - General] ===================================================================

param ( [Parameter(Mandatory=$true)][string]$vCenter,
		[Parameter(Mandatory=$true)][string]$ControllerCode,
		[Switch]$Test )

function InitializeEnvironment {
	Import-Module -Name INGPSModule -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "BackupControllerDisable"
	Connect-INGvCenter -vCenter $vCenter
}

function UninitializeEnvironment {
	Disconnect-INGvCenter -vCenter $vCenter
	Uninitialize-INGScript
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

InitializeEnvironment

Write-INGLog -Message ("Creating View for source VMs on {0}" -f $vCenter) -Color Green
$VMs = Get-View -ViewType VirtualMachine -Property Name,CustomValue,AvailableField,Summary.Config

Write-INGLog -Message ("Analyzing VMs") -Color Green
Write-INGLog -Message ("* ") -NoReturn

foreach ($VM in $VMs) {

	$VM_Pathname       = $VM.Summary.Config.VmPathName
	$VM_Datastore      = $VM_Pathname.SubString(1,$VM_Pathname.IndexOf("]") - 1)
	$VM_ControllerCode = $VM_Datastore.Split(".")[3]
	
	if ($VM_ControllerCode -ne $ControllerCode) { 
		Write-INGLog -Message ("{0}-{1} " -f $VM.Name, $VM_ControllerCode) -NoReturn -NoDateLog
		continue
	}
	
	$VM_BackupGroupOld = ($VM.CustomValue | Where {$_.Key -eq ($VM.AvailableField | Where {$_.Name -eq "BackupGroup"}).Key}).Value
	if (($VM_BackupGroupOld -eq "NoBackup") -or ($VM_BackupGroupOld -eq $null)) {
		Write-INGLog -Message ("{0}-{1}-{2} " -f $VM.Name, $VM_ControllerCode, $VM_BackupGroupOld) -NoReturn -NoDateLog -Color Yellow
		continue
	}
	
	$VM_BackupGroupArray = $VM_BackupGroupOld.Split("_")
	$VM_BackupGroupNew   = ("{0}_{1}_Gecici_{2}" -f $VM_BackupGroupArray[0],$VM_BackupGroupArray[1],$VM_BackupGroupArray[2])
	if (!$Test) {
		$VM.setCustomValue("BackupGroup",$VM_BackupGroupNew)
		Write-INGLog -Message ("{0}-{1}-{2} " -f $VM.Name, $VM_ControllerCode, $VM_BackupGroupNew) -NoReturn -NoDateLog -Color Cyan
	} else {
		Write-INGLog -Message ("{0}-{1}-{2} " -f $VM.Name, $VM_ControllerCode, $VM_BackupGroupNew) -NoReturn -NoDateLog -Color Cyan
	}
}

Write-INGLog -Message (" ") -NoDateLog

UninitializeEnvironment

# [END] ....................................................................................