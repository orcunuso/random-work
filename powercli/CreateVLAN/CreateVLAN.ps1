# Project     : Create VLANs
# Prepared by : Ozan Orçunus
#

# [FUNCTIONS - General] =================================================================

$Global:ScriptName = "CreateVLAN"

function Initialize-INGScript {
	[CmdletBinding()]
	param ( [Parameter(Mandatory=$true)][String]$ScriptName)
	
	If (Test-Path -Path "D:\Users\oorcunus\Documents\Scripts") { 
		$Global:ScrPath   = ("D:\Users\oorcunus\Documents\Scripts\{0}\" -f $ScriptName)
	} else {
		$Global:ScrPath   = ("C:\Scripts\{0}\" -f $ScriptName)
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
		CD "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\"
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

function DoesExist {
	param ( [Parameter(Mandatory=$true)]$Array,
			[Parameter(Mandatory=$true)]$Item )
	
	for ($i=0;$i -lt $Array.Count;$i++) {
		if ($Array[$i] -eq $Item) { return $true }
	}
	return $false
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

Initialize-INGScript -ScriptName $Global:ScriptName

$SourceVCenter  = "dc1vm"
$TargetVCenter  = "dc2vm"
$strSourceVDS   = "DC1.Dvs.Dmzbb.Middle"
$strTargetVDS   = "DC2.Dvs.Dmzbb.Middle"

Write-INGLog -Message ("VCENTERS: {0}->{1}" -f $SourceVCenter, $TargetVCenter)
Write-INGLog -Message ("SWITCHES: {0}->{1}" -f $strSourceVDS, $strTargetVDS)
Start-Sleep -Seconds 10

Connect-INGvCenter -vCenter $SourcevCenter
$SourcePortgroups = Get-VDPortgroup -VDSwitch $strSourceVDS
Disconnect-INGvCenter -vCenter $SourcevCenter

Connect-INGvCenter -vCenter $TargetvCenter
foreach ($SourcePortgroup in $SourcePortgroups) {
	if ($SourcePortgroup.Name -match "Uplink") { Continue }
	$TargetPortgroup = $null
	$TargetPortgroup = Get-VDPortgroup -Name $SourcePortgroup -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue
	if ($TargetPortgroup) {
		Write-INGLog -Message ("{0}: Portgroup exists" -f $TargetPortgroup.Name)
		Continue
	}
	$TargetPortgroup = New-VDPortgroup -Name $SourcePortgroup.Name -VDSwitch $strTargetVDS -Notes $SourcePortgroup.Notes -NumPorts $SourcePortgroup.NumPorts -VlanId $SourcePortgroup.VlanConfiguration.VlanId -PortBinding $SourcePortgroup.PortBinding
	if ($TargetPortgroup) {
		Write-INGLog -Message ("{0}: Portgroup successfully created" -f $TargetPortgroup.Name)
	} else {
		Write-INGLog -Message ("{0}: Portgroup cannot be created" -f $SourcePortgroup.Name) 
	}
	
	Start-Sleep -Seconds 5
}
Disconnect-INGvCenter -vCenter $TargetvCenter

Uninitialize-INGScript
