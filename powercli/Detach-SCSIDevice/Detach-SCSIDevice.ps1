# Project     : Detach SCSI Devices
# Prepared by : Ozan Orçunus
#

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)][string]$vCenter,
		[Parameter(Mandatory=$true)][string]$Cluster )

function Detach-SingleSCSIDisk {
    param(  [Parameter(Mandatory=$true)][string]$ClusterName,
        	[Parameter(Mandatory=$true)][string]$DisplayName )

	$Cluster = Get-Cluster -Name $ClusterName -ErrorAction:SilentlyContinue
	if ($Cluster) {
		foreach ($VMHost in ($Cluster | Get-VMHost | Sort-Object Name)) {
			$HostView = Get-View -Id $VMHost.Id
			$StorageSys = Get-View $HostView.ConfigManager.StorageSystem
			$Devices = $StorageSys.StorageDeviceInfo.ScsiLun
			Foreach ($Device in $Devices) {
				if ($Device.DisplayName -eq $DisplayName) {
					$LunUUID = $Device.Uuid
					Write-Host ("Detaching SCSI Device {0} ({2}) from host {1}" -f $Device.DisplayName, $VMHost.Name, $Device.CanonicalName)
					try {
						$StorageSys.DetachScsiLun($LunUUID)
					} catch {
						$ErrorMessage = $_.Exception.Message
						Write-Host $ErrorMessage -ForegroundColor Red
					}
				}
			}
		}
	} else {
		Write-Host "Cluster Object not found" -ForegroundColor Red
	}
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

$SCSIDevices = Get-Content "Detach-SCSIDevices.txt"

$VIServer = Connect-VIServer -Server $vCenter -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue
if ($VIServer) {
	Write-Host ("Connected to {0}" -f $vCenter)
} else {
	Write-Host ("Connection to {0} failed" -f $vCenter) -ForegroundColor Red
	Exit(1)
}

foreach ($SCSIDevice in $SCSIDevices) {

	if ($SCSIDevice.StartsWith("#")) { Continue }
	Write-Host ("<--- {1}:{0} -->" -f $SCSIDevice, $Cluster) -ForegroundColor Cyan
	try {
		Detach-SingleSCSIDisk -ClusterName $Cluster -DisplayName $SCSIDevice
	} catch {
		$ErrorMessage = $_.Exception.Message
		Write-Host $ErrorMessage -ForegroundColor Red
	}
}

Disconnect-VIServer -Confirm:$false

# [END] ....................................................................................














