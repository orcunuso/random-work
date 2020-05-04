# *********************************************************************
#
# Powershell script that removes and adds RDM disks
# to a single virtual machine
#
# USAGE: ./DR-RemoveAddRDM-Prod.ps1 VMName
#
# ASSUMPTIONS:
# All RDM Disks are RawPhysical
# Primary and Secondary Sites have identical LUNIDs per SCSI Devices
#
# *********************************************************************

function FindScsiDevice {
	param(	[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$ESX,
			[string]$RawDiskLunID  )

	$ScsiLuns = $ESX | Get-ScsiLun -LunType disk	
	foreach ($ScsiLun in $ScsiLuns) {
		$ScsiLunID = $ScsiLun.RuntimeName.Split("L")[1]
		if ($ScsiLunID -eq $RawDiskLunID) {
			return $ScsiLun.ConsoleDeviceName
		}
	}
	return $null
}

function Add-RawDiskExistingScsiController {
	param(	[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]$VM,
			[int32]$SCKey,
			[int32]$NodeID,
  			[string]$DevName)
	
	$Spec = New-Object VMware.Vim.VirtualMachineConfigSpec
	$Spec.deviceChange = @()
	$Spec.deviceChange += New-Object VMware.Vim.VirtualDeviceConfigSpec
	$Spec.deviceChange[0].operation = "add"
	$Spec.deviceChange[0].fileOperation = "create"
	$Spec.deviceChange[0].device = New-Object VMware.Vim.VirtualDisk
	$spec.deviceChange[0].device.key = -100
	$Spec.deviceChange[0].device.backing = New-Object VMware.Vim.VirtualDiskRawDiskMappingVer1BackingInfo
	$Spec.deviceChange[0].device.backing.fileName = ""
	$Spec.deviceChange[0].device.backing.deviceName = $DevName
	$Spec.deviceChange[0].device.backing.compatibilityMode = "physicalMode"
	$Spec.deviceChange[0].device.backing.diskMode = ""
	$Spec.deviceChange[0].device.connectable = New-Object VMware.Vim.VirtualDeviceConnectInfo
	$Spec.deviceChange[0].device.connectable.startConnected = $true
	$Spec.deviceChange[0].device.connectable.allowGuestControl = $false
	$Spec.deviceChange[0].device.connectable.connected = $true
	$Spec.deviceChange[0].device.controllerKey = $SCKey
	$Spec.deviceChange[0].device.unitNumber = $NodeID
	return $VM.ExtensionData.ReconfigVM_Task($Spec)
}

function Add-RawDiskNewScsiController {
	param(	[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]$VM,
			[string]$SCType,
			[string]$SCBusNumber,
			[int32]$NodeID,
  			[string]$DevName)
			
	$Spec = New-Object VMware.Vim.VirtualMachineConfigSpec
	$Spec.deviceChange = @()
	$Spec.deviceChange += New-Object VMware.Vim.VirtualDeviceConfigSpec
	$Spec.deviceChange[0].operation = "add"
	$Spec.deviceChange[0].fileOperation = "create"
	$Spec.deviceChange[0].device = New-Object VMware.Vim.VirtualDisk
	$Spec.deviceChange[0].device.key = -100
	$Spec.deviceChange[0].device.backing = New-Object VMware.Vim.VirtualDiskRawDiskMappingVer1BackingInfo
	$Spec.deviceChange[0].device.backing.fileName = ""
	$Spec.deviceChange[0].device.backing.deviceName = $DevName
	$Spec.deviceChange[0].device.backing.compatibilityMode = "physicalMode"
	$Spec.deviceChange[0].device.backing.diskMode = ""
	$Spec.deviceChange[0].device.connectable = New-Object VMware.Vim.VirtualDeviceConnectInfo
	$Spec.deviceChange[0].device.connectable.startConnected = $true
	$Spec.deviceChange[0].device.connectable.allowGuestControl = $false
	$Spec.deviceChange[0].device.connectable.connected = $true
	$Spec.deviceChange[0].device.controllerKey = -101
	$Spec.deviceChange[0].device.unitNumber = $NodeID
	$Spec.deviceChange += New-Object VMware.Vim.VirtualDeviceConfigSpec
	$Spec.deviceChange[1].operation = "add"
	
	switch ($SCType) {
		"VirtualLsiLogic"		{ $Spec.deviceChange[1].device = New-Object VMware.Vim.VirtualLsiLogicController }
		"VirtualLsiLogicSAS"	{ $Spec.deviceChange[1].device = New-Object VMware.Vim.VirtualLsiLogicSASController }
		"ParaVirtual"			{ $Spec.deviceChange[1].device = New-Object VMware.Vim.ParaVirtualSCSIController }
		default					{ $Spec.deviceChange[1].device = New-Object VMware.Vim.VirtualLsiLogicController }
	}
	
	$Spec.deviceChange[1].device.key = -101
	$Spec.deviceChange[1].device.controllerKey = 100
	$Spec.deviceChange[1].device.busNumber = $SCBusNumber
	$Spec.deviceChange[1].device.sharedBus = "noSharing"
	return $VM.ExtensionData.ReconfigVM_Task($Spec)
}
	
# ******************* MAIN SUB ***************************************************************

$Error.Clear()

if ($args.Count -ne 1) {
	Write-Host "ERROR 501: Invalid arguments"
	Write-Host "USAGE: ./drcRemoveAddRDM.ps1 VMName"
	Exit 501
}

$VM = Get-VM -Name $args[0]
$VMHost = $VM.VMHost
$AllDevices = $VM | Get-HardDisk
$RawDevices = $AllDevices | Where-Object { $_.DiskType -like "*Raw*" }

if (!$RawDevices) {	
	Write-Host ("No RawDisk found for: {0}" -f $VM.Name)
	Exit 0
}	

$ScsiControllers = Get-ScsiController -VM $VM

foreach ($ScsiController in $ScsiControllers) {
	
	$CreateScsiController = $False
	$ScsiControllerKey = $ScsiController.ExtensionData.Key
	$ScsiControllerType = $ScsiController.Type
	$ScsiControllerBusNumber = $ScsiController.ExtensionData.BusNumber
	$DeviceKeysAttached = $ScsiController.ExtensionData.Device
	
	if ($DeviceKeysAttached.Count -gt 1) { $CreateScsiController = $True }

	foreach ($DeviceKey in $DeviceKeysAttached) {

		$Device = $AllDevices | Where-Object { $_.ExtensionData.Key -eq $DeviceKey }
		$DeviceDiskType = $Device.DiskType
		if ($DeviceDiskType -eq "RawPhysical") {

			$DeviceVirtualNodeID = $Device.ExtensionData.UnitNumber
			$DeviceLunID = [Convert]::ToInt32($Device.DeviceName.SubString(8,2),16)
			Remove-HardDisk -HardDisk $RawDisk -DeletePermanently -Confirm:$False

			$DeviceConsoleName = FindScsiDevice $VMHost $DeviceLunID
			
			switch ($CreateScsiController) {
				$true	{ $VM = Add-RawDiskNewScsiController $VM $ScsiControllerType $ScsiControllerBusNumber $DeviceVirtualNodeID $DeviceConsoleName }
				$false	{ $VM = Add-RawDiskExistingScsiController $VM $ScsiControllerKey $DeviceVirtualNodeID $DeviceConsoleName }
			}
		}
	}
}

# EXTRA INFORMATION:
# $ScsiController.ExtensionData.Device.GetType() -> Int32[] (Array)
# $ScsiController.Type -> VirtualLsiLogic,VirtualLsiLogicSAS,ParaVirtual