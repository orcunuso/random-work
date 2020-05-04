# Project     : Detach Datastores
# Prepared by : Ozan Orçunus
#

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)] [string]$vCenter,
		[Parameter(Mandatory=$true)] [string]$DatastoreFileName,
		[Parameter(Mandatory=$false)][string]$HostsFileName )

function InitializeEnvironment {
	Import-Module -Name INGPSModule -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "DetachDatastore"
	Connect-INGvCenter -vCenter $vCenter
}

function UninitializeEnvironment {
	Disconnect-INGvCenter -vCenter $vCenter
	Uninitialize-INGScript
}

Function Detach-INGDatastoreSingleHost {
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline=$true)][VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl]$Datastore,
		[Parameter(Mandatory=$true)][VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$VMHost
	)
	Process {
		if (-not $Datastore) {
			Write-INGLog -Message ("No Datastore defined as input") -Color YELLOW
			Exit
		}
		Foreach ($ds in $Datastore) {
			$hostviewDSDiskName = $ds.ExtensionData.Info.vmfs.extent[0].Diskname
			$hostview = Get-View $VMHost.Id
			$StorageSys = Get-View $HostView.ConfigManager.StorageSystem
			$devices = $StorageSys.StorageDeviceInfo.ScsiLun
			Foreach ($device in $devices) {
				if ($device.canonicalName -eq $hostviewDSDiskName) {
					$LunUUID = $Device.Uuid
					Write-INGLog -Message "Detaching LUN $($Device.DisplayName) from host $($hostview.Name)..."
					try { 
						$StorageSys.DetachScsiLun($LunUUID)
					} catch {
						$ErrorMessage = $_.Exception.Message
						Write-INGLog -Message $ErrorMessage -Color RED
					}
				}
			}
		}
	}
}

Function Unmount-INGDatastoreSingleHost {
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline=$true)][VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl]$Datastore,
		[Parameter(Mandatory=$true)][VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$VMHost
	)
	Process {
		if (-not $Datastore) {
			Write-INGLog -Message ("No Datastore defined as input") -Color YELLOW
			Exit
		}
		Foreach ($ds in $Datastore) {
			$hostview = Get-View $VMHost.Id
			$StorageSys = Get-View $HostView.ConfigManager.StorageSystem
			Write-INGLog -Message "Unmounting VMFS Datastore $($DS.Name) from host $($hostview.Name)..."
			try {
				$StorageSys.UnmountVmfsVolume($ds.ExtensionData.Info.vmfs.uuid)
			} catch {
				$ErrorMessage = $_.Exception.Message
				Write-INGLog -Message $ErrorMessage -Color RED
			}
		}
	}
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

InitializeEnvironment
$strDatastores = Get-Content $DatastoreFileName

foreach ($strDatastore in $strDatastores) {

	if ($strDatastore.StartsWith("#")) { Continue }
	Write-INGLog -Message ("<--- {0} -->" -f $strDatastore) -Color Cyan
	try {
		$Datastore = $null
		$Datastore = Get-Datastore -Name $strDatastore -ErrorAction:SilentlyContinue
		if (!$Datastore) { 
			Write-INGLog -Message ("Datastore {0} not found" -f $strDatastore) 
			Continue 
		} 
		
		if ($HostsFileName) {
			$strVMHosts = Get-Content $HostsFileName
			foreach ($strVMHost in $strVMHosts) {
				if ($strVMHost.StartsWith("#")) { Continue }
				$VMHost = $null
				$VMHost = Get-VMHost -Name $strVMHost
				Unmount-INGDatastoreSingleHost -Datastore $Datastore -VMHost $VMHost
				Start-Sleep -Seconds 3
				Detach-INGDatastoreSingleHost -Datastore $Datastore -VMHost $VMHost
			}
		} else {
			Unmount-INGDatastore -Datastore $Datastore
			Start-Sleep -Seconds 3
			Detach-INGDatastore -Datastore $Datastore
		}
		
		
	} catch {
		$ErrorMessage = $_.Exception.Message
		Write-INGLog -Message $ErrorMessage -Severity "ERROR"
	}
}

UninitializeEnvironment

# [END] ....................................................................................














