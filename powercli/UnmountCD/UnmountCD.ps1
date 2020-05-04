# Subject     : Unmount CDROM from VMs
# Prepared by : Ozan Orçunus
# Script Name : UnmountCD.ps1
# Version     : 1.00

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)][string]$vCenter,
		[Parameter(Mandatory=$true)][string]$VMHost,
		[Parameter(Mandatory=$false)][string]$Action )

function InitializeEnvironment {
	Import-Module -Name ModING -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "UnmountCD"
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

$VMs = Get-VMHost -Name ("{0}.mydomain.local" -f $VMHost) | Get-VM
$CountSuccess = 0
$CountMounted = 0

foreach ($VM in $VMs) {
	$CDDrive = Get-CDDrive -VM $VM | where { $_.IsoPath.Length -gt 0 -OR $_.HostDevice.Length -gt 0 }
	if ($CDDrive -eq $null) { 
		$CountSuccess++
	} else {
		Write-INGLog -Message ("CD Drive is mounted: {0}-{1}" -f $VM.Name, $CDDrive.IsoPath) 
		$CountMounted++
		if ($Action -eq "UNMOUNT") {
			try {
				Set-CDDrive -CD $CDDrive -NoMedia -Confirm:$False | Out-Null
				Write-INGLog -Message ("Successfully unmounted for {0}" -f $VM.Name)
			} catch {
				$ErrorMessage = $_.Exception.Message
				Write-INGLog -Message $ErrorMessage -Color Red
			}
		}
	}
}

Write-INGLog -Message ("Success Count: {0} - Mounted Count: {1}" -f $CountSuccess, $CountMounted)
UninitializeEnvironment