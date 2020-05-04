# Project     : Migrate VM from one vCenter to another
# Prepared by : Ozan Orçunus
#

# [FUNCTIONS - General] =================================================================

$Global:ScriptName = "x86VMMigration"

function Initialize-INGScript {
	[CmdletBinding()]
	param ( [Parameter(Mandatory=$true)][String]$ScriptName)
	
	If (Test-Path -Path "D:\Users\oorcunus\Documents\Scripts") { 
		$Global:ScrPath   = ("D:\Users\oorcunus\Documents\Scripts\{0}\" -f $ScriptName)
	} else {
		$Global:ScrPath   = ("C:\Scripts\x86VMMigration\")
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

$SourceVCenter  = ""
$TargetVCenter  = ""
$ProblemVLANs   = ("0","3","5","7","8")
$ScriptInterval = 3  #minutes
$SleepInterval  = 45 #seconds

do { 	#============================= MAIN LOOP =================================
	
	if ((Get-Content -Path $Global:CtrlFile) -ne "GO") { break }
	
	do {
		$DateKontrol = Get-Date
		if (($DateKontrol.Minute % $ScriptInterval) -eq 0) { break }
		Start-Sleep -Seconds $SleepInterval
	} while ($true)

	Connect-INGvCenter -vCenter $SourcevCenter
	
	$Info_VM = Get-VM -Name "X86MIGRATION_DOWN"
	Set-Annotation -Entity $Info_VM -CustomAttribute "Info" -Value (Get-Date).ToString("yyyyMMddhhmm") -Confirm:$false | Out-Null
	$Info_VM = $null
	
	$ShutDownVMs    = Get-VM | Where-Object {$_.PowerState -eq "PoweredOff"} | Where-Object {$_.Name -notmatch "_DOWN"}
	$MigrateVMs     = @()
	$PortGroups     = Get-View -ViewType Network -Property Name
	$Folders        = Get-View -ViewType Folder -Property Name
	
	foreach ($VM in $ShutDownVMs) {
		if (!$VM.ExtensionData.Config) { 
			if ($VM.Name) { Write-INGLog -Message ("{0}: This VM has no config, probably being deployed from a template" -f $VM.Name) -Color Yellow }
			Continue
		}
		
		$Migratable = $true
		$Networks = $VM.ExtensionData.Network
		foreach ($Network in $Networks) {
			$PortGroup = $PortGroups | Where-Object { $_.MoRef -eq $Network }
			$NetworkVLAN = $PortGroup.Name.Split(".")[3]
			if (DoesExist -Array $ProblemVLANs -Item $NetworkVLAN.Substring(0,1)) {
				Write-INGLog -Message ("{0}: This VM will not be migrated, VLANID {1}" -f $VM.Name, $NetworkVLAN) -Color Cyan
				$Migratable = $false
			}
			if (($PortGroup.Name -match "Ecbb") -or ($PortGroup.Name -match "Imkb")) {
				Write-INGLog -Message ("{0}: This VM will not be migrated, VLANID {1}" -f $VM.Name, $NetworkVLAN) -Color Cyan
				$Migratable = $false
			}
		}
		
		if ($Migratable) {
			Write-INGLog -Message ("{0}: This VM will be migrated" -f $VM.Name) -Color Cyan
			$MigrateVMs += $VM
		} else {
			#Start-VM -VM $VM -RunAsync | Out-Null
		}
	}
	
	Start-Sleep -Seconds 5
	
	#------ Take Snapshot, Upgrade and Unregister VM ----------------------------------------------
	foreach ($VM in $MigrateVMs) {
		
		$strVersion = $VM.ExtensionData.Config.Version	
		if (($VM.Name -match "JAG") -or ($VM.Name -match "CARD")) {
			Write-INGLog -Message ("{0}: This is a jaguar or cardweb server, will not be upgraded" -f $VM.Name)
		} else {		
			if ($strVersion -eq "vmx-09") {
				Write-INGLog -Message ("{1}: Hardware Version is {0}, no action required" -f $strVersion, $VM.Name)
			} else {
				Write-INGLog -Message ("{1}: Hardware Version is {0}, taking snapshot and upgrading to vmx-09" -f $strVersion, $VM.Name)
				#$Task = New-Snapshot -VM $VM -Name "Before x86 Migration" -Description "Before x86 Migration, 1 day" -Confirm:$false
				#$VM.ExtensionData.UpgradeVM("vmx-09")
			}
		}
		
		$VM.ExtensionData.UnregisterVM()
		Write-INGLog -Message ("{1}: VM has been unregistered from {0}" -f $SourcevCenter, $VM.Name)
	}

	#============================= TARGET VCENTER OPERATIONS =================================
		
	if ($MigrateVMs.Count -gt 0) { Connect-INGvCenter -vCenter $TargetVCenter }

	foreach ($VM in $MigrateVMs) {
		
		$TargetCluster = ""
		if ($VM.VMHost.Name -match "") { $TargetCluster = ""; $ClusterCode = "" }
		if ($VM.VMHost.Name -match "") { $TargetCluster = ""; $ClusterCode = "" }
		
		#------ Register VM ---------------------------------------------- 
		$New_VMHost        = Get-Cluster -Name ("DC1.{0}" -f $TargetCluster) | Get-VMHost | Where-Object {$_.ConnectionState -eq "Connected"} | Get-Random
		$New_ResourcePool  = Get-ResourcePool -Name ("DC1.{0}.Generic" -f $TargetCluster)
		$Old_Folder        = $Folders | Where-Object {$_.MoRef -eq ("Folder-{0}" -f $VM.ExtensionData.Parent.Value)}
		$New_Folder        = Get-Folder -Name $Old_Folder.Name | Where-Object {$_.Parent -match "FolderGroup"}
		$New_VMXPath       = $VM.ExtensionData.Summary.Config.VmPathName
		Write-INGLog -Message ("{0}-{1}-{2}" -f $Old_Folder.Name, $New_Folder.Name, $New_VMXPath)
		$New_Folder.ExtensionData.RegisterVM($New_VMXPath,$VM.Name,$false,$New_ResourcePool.ExtensionData.MoRef,$New_VMHost.ExtensionData.MoRef) | Out-Null
		Start-Sleep -Milliseconds 2000
		$NewVM = Get-VM -Name $VM.Name

		if (!$NewVM) { Write-INGLog -Message ("{0}: VM cannot be registered successfully" -f $VM.Name) -Color Red; Continue }
			else { Write-INGLog -Message ("{0}: VM registered successfully" -f $VM.Name) }

		#------ Update Network Label ------------------------------------
		$NetDevices = $VM.ExtensionData.Config.Hardware.Device | Where-Object {$_.MacAddress -ne $null}
		$NICs       = Get-NetworkAdapter -VM $NewVM
		foreach ($NIC in $NICs) {
			foreach ($NetDevice in $NetDevices) {
				if ($NIC.MacAddress -eq $NetDevice.MacAddress) {
					$PortGroupMoRef = ("DistributedVirtualPortgroup-{0}" -f $NetDevice.Backing.Port.PortgroupKey)
					$PortGroup      = $PortGroups | Where-Object { $_.MoRef -eq $PortGroupMoRef }					
					$Old_PortGroup  = $PortGroup.Name.Split(".")
					$New_PortGroup = ("Dvp.{2}bb.{0}.{1}" -f $Old_PortGroup[2], $Old_PortGroup[3], $ClusterCode)
					Write-INGLog -Message ("{0}: Updating virtual NIC label: {1}" -f $VM.Name, $New_PortGroup)
					Set-NetworkAdapter -NetworkAdapter $NIC -NetworkName $New_PortGroup -Confirm:$false | Out-Null
				}
			}
		}

		#------ Update Annotations ----------------------------------------
		Write-INGLog -Message ("{0}: Updating annotations and setting advanced parameters" -f $VM.Name)
		$Info_Application = ($VM.ExtensionData.CustomValue | Where {$_.Key -eq ($VM.ExtensionData.AvailableField | Where {$_.Name -eq "Application"}).Key}).Value
		$Info_Description = ($VM.ExtensionData.CustomValue | Where {$_.Key -eq ($VM.ExtensionData.AvailableField | Where {$_.Name -eq "Description"}).Key}).Value
		$Info_Environment = ($VM.ExtensionData.CustomValue | Where {$_.Key -eq ($VM.ExtensionData.AvailableField | Where {$_.Name -eq "Environment"}).Key}).Value
		$Info_Responsible = ($VM.ExtensionData.CustomValue | Where {$_.Key -eq ($VM.ExtensionData.AvailableField | Where {$_.Name -eq "Responsible"}).Key}).Value
		$Info_DeadLine    = ($VM.ExtensionData.CustomValue | Where {$_.Key -eq ($VM.ExtensionData.AvailableField | Where {$_.Name -eq "Dead Line"  }).Key}).Value
		$Info_Department  = ($VM.ExtensionData.CustomValue | Where {$_.Key -eq ($VM.ExtensionData.AvailableField | Where {$_.Name -eq "Department" }).Key}).Value
		$Info_BackupGroup = ($VM.ExtensionData.CustomValue | Where {$_.Key -eq ($VM.ExtensionData.AvailableField | Where {$_.Name -eq "BackupGroup"}).Key}).Value
			if (!$Info_Application) { $Info_Application = "<Not Set>" }
			if (!$Info_Description) { $Info_Description = "<Not Set>" }
			if (!$Info_Environment) { $Info_Environment = "<Not Set>" }
			if (!$Info_Responsible) { $Info_Responsible = "<Not Set>" }
			if (!$Info_DeadLine)    { $Info_DeadLine    = "<Not Set>" }
			if (!$Info_Department)  { $Info_Department  = "<Not Set>" }
			if (!$Info_BackupGroup) { $Info_BackupGroup = "<Not Set>" }
		Set-Annotation -Entity $NewVM -CustomAttribute "Application" -Value $Info_Application -Confirm:$false | Out-Null
		Set-Annotation -Entity $NewVM -CustomAttribute "Description" -Value $Info_Description -Confirm:$false | Out-Null
		Set-Annotation -Entity $NewVM -CustomAttribute "Environment" -Value $Info_Environment -Confirm:$false | Out-Null
		Set-Annotation -Entity $NewVM -CustomAttribute "Department"  -Value $Info_Department  -Confirm:$false | Out-Null
		Set-Annotation -Entity $NewVM -CustomAttribute "Responsible" -Value $Info_Responsible -Confirm:$false | Out-Null
		Set-Annotation -Entity $NewVM -CustomAttribute "Dead Line"   -Value $Info_DeadLine    -Confirm:$false | Out-Null
		Set-Annotation -Entity $NewVM -CustomAttribute "BackupGroup" -Value $Info_BackupGroup -Confirm:$false | Out-Null

		#------ Update Advanced Parameters --------------------------------
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
			$NewVM.ExtensionData.ReconfigVM($Spec)
		} catch {
			$ErrorMessage = $_.Exception.Message
			Write-INGLog -Message $ErrorMessage -Color RED
		}

		#------ Poweron VM -------------------------------------------------
		
		Write-INGLog -Message ("{0}: Starting VM, " -f $VM.Name) -NoReturn
		
		Start-VM -VM $NewVM -RunAsync | Out-Null
		Start-Sleep -Milliseconds 12000
		$VMQuestion = Get-VMQuestion -VM $NewVM
		if ($VMQuestion) {
			Write-INGLog -Message ("pending VM question exists, responding") -NoDateLog
			Set-VMQuestion -VMQuestion $VMQuestion -DefaultOption -Confirm:$false
		} else {
			Write-INGLog -Message ("no question exists") -NoDateLog
		}
	}

	$ShutDownVMs  = $null
	$MigrateVMs   = $null
	$PortGroups   = $null
	$Folders      = $null
	
	if ($Global:DefaultVIServer) { 
		Disconnect-VIServer * -Confirm:$false -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue
		Write-INGLog -Message ("Disconnected from all vCenter Servers")
		$host.ui.RawUI.WindowTitle = ("!!!!! NOT CONNECTED TO ANY VCENTER SERVERS !!!!!")
	}
	
	Start-Sleep -Seconds 5
} while ($true)

Uninitialize-INGScript
