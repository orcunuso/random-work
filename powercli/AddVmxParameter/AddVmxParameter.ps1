# Project     : Add Desired VMX Parameters
# Prepared by : Ozan Orçunus
#

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$false)] [string]$vCenter,
		[Parameter(Mandatory=$false)] [string]$Filter  )
		
$Global:ScriptName = "AddVmxParameter"

function Initialize-INGScript {
	[CmdletBinding()]
	param ( [Parameter(Mandatory=$true)][String]$ScriptName)
	
	If (Test-Path -Path "D:\Users\oorcunus\Documents\Scripts") { 
		$Global:ScrPath   = ("D:\Users\oorcunus\Documents\Scripts\{0}\" -f $ScriptName)
	} else {
		$Global:ScrPath   = ("C:\Scripts\")
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
	if ($Global:DefaultVIServer) { 
		Disconnect-VIServer * -Confirm:$false -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue
		Write-INGLog -Message ("Disconnected from all vCenter Servers")
		$host.ui.RawUI.WindowTitle = ("!!!!! NOT CONNECTED TO ANY VCENTER SERVERS !!!!!")
	}
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

$ArrayParams =  @()
$ArrayValues =  @()
$ArrayParams += "isolation.tools.autoInstall.disable";				$ArrayValues += "true"
$ArrayParams += "isolation.tools.copy.disable";						$ArrayValues += "true"
$ArrayParams += "isolation.tools.paste.disable";					$ArrayValues += "true"
$ArrayParams += "isolation.tools.dnd.disable";						$ArrayValues += "true"
$ArrayParams += "isolation.tools.setGUIOptions.enable";				$ArrayValues += "false"
$ArrayParams += "isolation.tools.diskShrink.disable";				$ArrayValues += "true"
$ArrayParams += "isolation.tools.diskWiper.disable";				$ArrayValues += "true"
$ArrayParams += "isolation.tools.hgfsServerSet.disable";			$ArrayValues += "true"
$ArrayParams += "isolation.tools.guestInitiatedUpgrade.disable";	$ArrayValues += "true"
$ArrayParams += "isolation.device.connectable.disable";				$ArrayValues += "true"
$ArrayParams += "isolation.device.edit.disable";					$ArrayValues += "true"
$ArrayParams += "log.keepOld";										$ArrayValues += "10"
$ArrayParams += "log.rotateSize";									$ArrayValues += "100000"
$ArrayParams += "RemoteDisplay.maxConnections";						$ArrayValues += "1"
$ArrayParams += "tools.setInfo.sizeLimit";							$ArrayValues += "1048576"
$ArrayParams += "tools.guestlib.enableHostInfo";					$ArrayValues += "false"
$ArrayParams += "vmci0.unrestricted";								$ArrayValues += "false"
$VMs = $null

for ($i=0; $i -lt $ArrayParams.Count; $i++) { 
	Write-INGLog ("ADVANCED PARAMETER: {0}->{1}" -f $ArrayParams[$i], $ArrayValues[$i]) 
}

if ($vCenter -and $Filter) {
	
	$VMs = Get-VM -Name $Filter | Get-View
	
	foreach ($VM in $VMs) {
	
		Write-INGLog ("Setting advanced parameters for: {0}" -f $VM.Name) -Color Cyan
		$Spec = New-Object VMware.Vim.VirtualMachineConfigSpec
		$Spec.Flags = New-Object VMware.Vim.VirtualMachineFlagInfo
		$Spec.Tools = New-Object VMware.Vim.ToolsConfigInfo
		$Spec.Flags.enableLogging = $true
		$Spec.Tools.SyncTimeWithHost = $false
		$Spec.Tools.ToolsUpgradePolicy = "manual"
		
		for ($i=0; $i -lt $ArrayParams.Count; $i++) {
			$Spec.ExtraConfig += New-Object VMware.Vim.OptionValue
			$Spec.ExtraConfig[$i].Key   = $ArrayParams[$i]
			$Spec.ExtraConfig[$i].Value = $ArrayValues[$i]
		}
		
		try {
			$VM.ReconfigVM($Spec)
			Write-INGLog ("Advanced parameters successfully applied")
		} catch {
			$ErrorMessage = $_.Exception.Message
			Write-INGLog -Message $ErrorMessage -Color RED
		}
	}
	
} else {
	Write-INGLog ("Missing Parameters: vCenter or Filter") -Color Red
}

Disconnect-INGvCenter -vCenter $Global:DefaultVIServer.Name
Uninitialize-INGScript

# [END] ....................................................................................

#log.rotateSize is deprecated after ESXi5.1, using an log trottling algo instead. (kb.vmware.com/kb/8182749)
#$VM.ExtensionData.Config.ExtraConfig === Get-AdvancedSetting

#Shutdown
#Upgrade Hardware (vmx-9)
#Take Annotations, CPU count, network label, vmx path
#Unregister VM

#Register VM
#Configure Network label
#Add Annotations
#Add Parameters
#Poweron
#Answer Question