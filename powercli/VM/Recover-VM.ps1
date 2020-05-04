function Remove-RawDisks {
	param($VM, $HDname, $DelFlag)
  
	$VM_View = Get-View -Id $VM.ID

	foreach($Dev in $VM_View.Config.Hardware.Device) {
		if ($Dev.DeviceInfo.Label -eq $HDname) {
			$Key = $Dev.Key
			$FileName = $Dev.Backing.FileName
		}
	}

	$Spec = New-Object VMware.Vim.VirtualMachineConfigSpec
	$Spec.deviceChange = @()
	$Spec.deviceChange += New-Object VMware.Vim.VirtualDeviceConfigSpec
	$Spec.deviceChange[0].Device = New-Object VMware.Vim.VirtualDevice
	$Spec.deviceChange[0].Device.Key = $Key
	$Spec.deviceChange[0].Operation = "remove"

	$VM_View.ReconfigVM_Task($Spec)

	if ($DelFlag) {
		$SvcRef = New-Object VMware.Vim.ManagedObjectReference
		$SvcRef.Type = "ServiceInstance"
		$SvcRef.Value = "ServiceInstance"
		$ServiceInstance = Get-View $SvcRef
		$FileMgr = Get-View $ServiceInstance.Content.FileManager
		$DataCenter = (Get-View -Id (Get-Datacenter).Id).get_MoRef()
		$FileMgr.DeleteDatastoreFile_Task($FileName, $DataCenter)
	}
}

function add-HD {
  param($VMname, $DSname, $Filename, $SCSIcntrl)

  $vm = Get-View (Get-VM $VMname).ID
  $ds = Get-View (Get-Datastore -Name $DSname).ID
  foreach($dev in $vm.config.hardware.device){
    if ($dev.deviceInfo.label -eq $SCSIcntrl){
       $CntrlKey = $dev.key
     }
  }
  $Unitnumber = 0
  $DevKey = 0
  foreach($dev in $vm.config.hardware.device){
    if ($dev.controllerKey -eq $CntrlKey){
       if ($dev.Unitnumber -gt $Unitnumber){$Unitnumber = $dev.Unitnumber}
       if ($dev.key -gt $DevKey) {$DevKey = $dev.key}
     }
  }

  $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
  $spec.deviceChange = @()
  $spec.deviceChange += New-Object VMware.Vim.VirtualDeviceConfigSpec

  $spec.deviceChange[0].device = New-Object VMware.Vim.VirtualDisk
  $spec.deviceChange[0].device.backing = New-Object VMware.Vim.VirtualDiskFlatVer2BackingInfo
  $spec.deviceChange[0].device.backing.datastore = $ds.MoRef
  $spec.deviceChange[0].device.backing.fileName = "[" + $DSname + "] " + $Filename
  $spec.deviceChange[0].device.backing.diskMode = "independent_persistent"
  $spec.deviceChange[0].device.key = $DevKey + 1
  $spec.deviceChange[0].device.unitnumber = $Unitnumber + 1
  $spec.deviceChange[0].device.controllerKey = $CntrlKey
  $spec.deviceChange[0].operation = "add"

  $vm.ReconfigVM_Task($spec)
}


























#################################################### VM shutdown

$VMGuest = ShutDown-VMGuest -VM $VM -Confirm:$False

#################################################### SnapMirror Update




#################################################### SnapMirror Update




#################################################### SnapMirror Break




#################################################### Configure reverse replication




#################################################### Lun Map




#################################################### Rescan DataStores

$VMHosts = Get-VMHost
$VMHostStorageInfo = Get-VMHostStorage -VMHost $VMHosts -RscanAllHBA

#################################################### Add DataStores




#################################################### Add VMs to Inventory

$Clusters = Get-Cluster
foreach ($Cluster in $Clusters) {
	
	$Datastores = $Cluster | Get-VMHost | Select-Object -First 1 | Get-Datastore -Name *DRC.*
	$VMHosts = Get-VMHost | Where-Object { $_.ConnectionState -eq "Connected" }
	$DefaultLocation = Get-Folder -Name DefaultFolder
	
	foreach ($Datastore in $Datastores) {
		$Datastore_View = Get-View -Id $Datastore.Id
		$SearchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
		$SearchSpec.MatchPattern = "*.vmx"
		$DSBrowser = Get-View $Datastore_View.Browser
		$DatastorePath = "[" + $Datastore_View.Summary.Name + "]"
		$SearchResult = $DSBrowser.SearchDatastoreSubFolders($DatastorePath, $SearchSpec) | foreach {$_.FolderPath + ($_.File | Select-Object Path).Path}
		foreach ($VMXFile in $SearchResult) {
			$index = Get-Random -Maximum $VMHosts.Count -Minimum 0
			$VM = New-VM -VMFilePath $VMXFile -VMHost $VMHost[$index] -Location $DefaultLocation
			$Tag = $VM.Notes.Split("|")[0].Trim()
			$ResourcePool = Get-ResourcePool -Name $Tag*
			$Folder = Get-Folder -Name $Tag* | Where-Object { $_.Name -notmatch ".Local" }
			$VM = Move-VM -VM $VM -Destination $Folder
			$VM = Move-VM -VM $VM -Destination $ResourcePool
		}
	}
}

#################################################### Remove Old RDMs

$VMs = Get-Folder -Name Recovery | Get-VM
foreach ($VM in $VMs) {
	$RawDisk = $VM | Get-HardDisk | Where-Object { $_.DiskType -eq "RawPhysical" }
	if (!$RawDisk) { Continue }	
	
	if (!$RawDisk.Count) { 
		$ScsiConID = $RawDisk.ExtensionData.ControllerKey
		$ScsiBusID = $RawDisk.ExtensionData.UnitNumber
		$ScsiCanID = $RawDisk.ScsiCanonicalName
		$HardDskID = $RawDisk.ExtensionData.DeviceInfo.Label
		Remove-HardDisk -HardDisk $RawDisk -DeletePermanently -Confirm:$False
	}
	else {
		foreach ($RDM in $RawDisk) {
			Remove-HardDisk -HardDisk $RDM -DeletePermanently -Confirm:$False
		}
	} 
}

#################################################### Add New RDMs




#################################################### Change VLANs of VMs




#################################################### Power On VMs





#################################################### Change IP Address





#################################################### Change Static Routes





#################################################### Restart VMs








#========================== VARSAYIMLAR ======================================================================
#
# Add VMs to Inventory: Tüm Hostlarýn ayný datastore'lara eriþtiði varsayýlýyor. Yoksa -First 1 doðru sonuç vermeyebilir.
# Add VMs to Inventory: Clusterlarda birden fazla host olduðu varsayýlýyor. Yoksa $VMHosts.Count hata verir.

