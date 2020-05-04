# Project     : Bulk Storage vMotion
# Prepared by : Ozan Orçunus
#

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)]  [string]$vCenter,
		[Parameter(Mandatory=$false)] [string]$Cluster,
		[Parameter(Mandatory=$false)] [string]$Datastore,
		[Parameter(Mandatory=$false)] [string[]]$VMNames,
		[Switch]$Test )
		
$Global:ScriptName = "BulkStorageVmotion"

function Initialize-INGScript {
	[CmdletBinding()]
	param ( [Parameter(Mandatory=$true)][String]$ScriptName)
	
	If (Test-Path -Path "D:\Users\oorcunus\Documents\Scripts") { 
		$Global:ScrPath   = ("D:\Users\oorcunus\Documents\Scripts\{0}\" -f $ScriptName)
	} else {
		$Global:ScrPath   = ("C:\Scripts\{0}\")
	}
	
	$Global:LogFile   = ("{0}{1}.log"      -f $Global:ScrPath,$ScriptName)
	$Global:XlsFile   = ("{0}{1}.xlsx"     -f $Global:ScrPath,$ScriptName)
	$Global:CtrlFile  = ("{0}{1}.ctrl"     -f $Global:ScrPath,$ScriptName)
	$Global:OutFile   = ("{0}{1}_Out.xlsx" -f $Global:ScrPath,$ScriptName)
	$Global:ScrptName = $ScriptName
	
	Confirm-INGPowerCLI $Global:ScrPath
	Write-INGLog (" ")
	Write-INGLog ("***************** Script started *******************")
}

function Confirm-INGPowerCLI {
	param ([String]$PSPath)
	$VMSnapin = (Get-PSSnapin | Where {$_.Name -eq "VMware.VimAutomation.Core"}).Name
	if ($VMSnapin -ne "VMware.VimAutomation.Core") {
		CD "C:\Program Files\VMware\Infrastructure\vSphere PowerCLI\Scripts\"
		Add-PSSnapin VMware.VimAutomation.Core
		.\Initialize-PowerCLIEnvironment.ps1
		CD $PSPath
	}
}

function Uninitialize-INGScript {
	Write-INGLog ("***************** Script completed *****************")
	$Global:ScrPath   = $null
	$Global:LogFile   = $null
	$Global:XlsFile   = $null
	$Global:CtrlFile  = $null
	$Global:OutFile   = $null
}

function Write-INGLog {
	[CmdletBinding()]
	param ( [Parameter(Mandatory=$true)][String]$Message, 
			[string]$Color,
			[switch]$NoReturn,
			[switch]$NoDateLog)
	
	if (!$Color) { $Color = "WHITE" }
	if ($NoDateLog) { $LogMessage = $Message }
		else { $LogMessage = (Get-Date).ToString() + " | " + $Message }
	
	Write-Host $LogMessage -ForegroundColor $Color -NoNewline:$NoReturn
	Out-File -InputObject $LogMessage -FilePath $Global:LogFile -Append -NoClobber -Confirm:$false -ErrorAction:SilentlyContinue
}

function Connect-INGvCenter {
	param ( [Parameter(Mandatory=$true)][String]$vCenter, 
			[System.Management.Automation.PSCredential]$Credential)
			
	$vCenterFQDN = $vCenter
	switch ($vCenter) {
		"dc1vm" { $vCenterFQDN = "dc1vm.mydomain.local"   }
		"dc2vm" { $vCenterFQDN = "dc2vm.mydomain.local"   }
		"DC1VC"  { $vCenterFQDN = "dc1vc01.mydomain.local" }
		"PREVC"  { $vCenterFQDN = "dc1vc03.mydomain.local" }
		"DC2VC"  { $vCenterFQDN = "dc2vc01.mydomain.local" }
	}
	try {
		if ($Credential) {
			Connect-VIServer -Server $vCenterFQDN -Credential $Credential -WarningAction:SilentlyContinue | Out-Null
		} else {
			Connect-VIServer -Server $vCenterFQDN -WarningAction:SilentlyContinue | Out-Null
		}
		Write-INGLog ("Connected to " + $vCenterFQDN)
		$host.ui.RawUI.WindowTitle = ("CONNECTED TO " + $vCenter)
	} catch {
		Write-INGLog ("Cannot connect to " + $vCenterFQDN) -Color RED
	}
}

function Disconnect-INGvCenter {
	[CmdletBinding()]
	param ([String]$vCenter)
	
	$vCenterFQDN = $vCenter
	switch ($vCenter) {
		"dc1vm" { $vCenterFQDN = "dc1vm.mydomain.local"   }
		"dc2vm" { $vCenterFQDN = "dc2vm.mydomain.local"   }
		"DC1VC"  { $vCenterFQDN = "dc1vc01.mydomain.local" }
		"PREVC"  { $vCenterFQDN = "dc1vc03.mydomain.local" }
		"DC2VC"  { $vCenterFQDN = "dc2vc01.mydomain.local" }
	}
	
	Disconnect-VIServer -Confirm:$false -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue | Out-Null
	if ($vCenterFQDN) { Write-INGLog -Message ("Disconnected from " + $vCenterFQDN) }
		else { Write-INGLog -Message ("Disconnected from vCenter Server") }
	$host.ui.RawUI.WindowTitle = ("!!!!! NOT CONNECTED TO ANY VCENTER SERVERS !!!!!")
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

Initialize-INGScript -ScriptName $Global:ScriptName
Connect-INGvCenter -vCenter $vCenter

if ($VMNames) { 
	$VMs = Get-VM -Name $VMNames
} else {
	if ($Cluster)   { $VMs = Get-Cluster   -Name $Cluster   | Get-VM | Sort-Object Name }
	if ($Datastore) { $VMs = Get-Datastore -Name $Datastore | Get-VM | Where-Object {$_.PowerState -eq "PoweredOn"} | Sort-Object Name }
}

$TimeToStop = Get-Date -Year (Get-Date).Year -Month (Get-Date).Month -Day (Get-Date).Day -Hour 23 -Minute 30 -Second 0
$Count = 0

foreach ($VM in $VMs) {
	
	#------------------------------------------------
	
	$Count++
	$TimerDone = ((Get-Date) -gt $TimeToStop)
	if ((Get-Content -Path $Global:CtrlFile) -eq "STOP") { Write-INGLog -Message ("Script terminated by user input!!!") -Color Yellow; break }
	if ($TimerDone) { Write-INGLog -Message ("Enough for today, see you tomorrow :)") -Color Yellow; break }
	
	#------------------------------------------------
	
	$Datastore_Source = $VM.ExtensionData.Summary.Config.VmPathName.SubString(1,$VM.ExtensionData.Summary.Config.VmPathName.IndexOf("]") - 1)
	if ($Datastore_Source.Contains(".EMC")) {
		Write-INGLog -Message ("{2} -> Source Datastore for {0}: {1}" -f $VM.Name, $Datastore_Source, $Count)
		Continue
	}
	
	if ($Cluster -match "RSFBB")    { $Datastores = Get-Datastore -Name LOC.Rsfbb.S*.EMC | Sort-Object FreeSpaceGB -Descending }
	if ($Cluster -match "DMZBB")    { $Datastores = Get-Datastore -Name LOC.Dmzbb.S*.EMC | Sort-Object FreeSpaceGB -Descending }
	if ($Cluster -match "DMZOWLBB") { $Datastores = Get-Datastore -Name LOC.Dmzbb.S*.EMC | Sort-Object FreeSpaceGB -Descending }
	$Datastore_Target = $Datastores | Select-Object -First 1
	$Datastore_FreeGB = [Math]::Round($Datastore_Target.FreeSpaceGB) - [Math]::Round($VM.ProvisionedSpaceGB)
	if ($Datastore_FreeGB -lt ([Math]::Round($Datastore_Target.CapacityGB)*0.1)) {
		Write-INGLog -Message ("No available datastore found, please check free spaces") -Color Red
		Continue
	}
	
	try {
		if ($Test) {
			Write-INGLog -Message ("TEST: Target Datastore:{0} FreeSpace:{1}GB" -f $Datastore_Target.Name, $Datastore_FreeGB)
			Write-INGLog -Message ("TEST: Move-VM -VM {0} -Datastore {1} -Confirm:false" -f $VM.Name, $Datastore_Target.Name)
		} else {
			Write-INGLog -Message ("{0} -> Target Datastore:{1} VM:{2} FreeSpace:{3}GB" -f $Count, $Datastore_Target.Name, $VM.Name, $Datastore_FreeGB)
			Move-VM -VM $VM -Datastore $Datastore_Target -Confirm:$false | Out-Null
			Start-Sleep -Seconds 15
		}	
	} catch {
		$ErrorMessage = $_.Exception.Message
		Write-INGLog -Message $ErrorMessage -Color RED
	}
}

if ($Global:DefaultVIServer) { 
		Disconnect-VIServer * -Confirm:$false -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue
		Write-INGLog -Message ("Disconnected from all vCenter Servers")
		$host.ui.RawUI.WindowTitle = ("!!!!! NOT CONNECTED TO ANY VCENTER SERVERS !!!!!")
	}
Uninitialize-INGScript

# [END] ....................................................................................

