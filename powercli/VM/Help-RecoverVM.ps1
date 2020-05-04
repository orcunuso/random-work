Get-VM | Get-VMQuestion | Set-VMQuestion -Option “I moved it” -Confirm:$false
Add-Type -TypeDefinition @'
public class myNIC {
    public string VMname;
	public string Mac;   
	public string Ip;
	public string Netmask;
	public string Gateway;
	public string[] Dns;
}
public class myVM {
	public string Name;
	public myNIC[] Nics;
	public int GetNICCount { return Nics.Count; }
}
'@

[myVM[]]$VMs = @()



$sw = New-Object System.IO.StreamWriter("C:\dba\powershell\files\AvailableMBytes.csv",$false)
$sw.WriteLine($string)
$sw.close()
$sw = $null

# Normla RDM ekleme, VirtualNOdeID=3
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec[] (1)
$spec.deviceChange[0] = New-Object VMware.Vim.VirtualDeviceConfigSpec
$spec.deviceChange[0].operation = "add"
$spec.deviceChange[0].fileOperation = "create"
$spec.deviceChange[0].device = New-Object VMware.Vim.VirtualDisk
$spec.deviceChange[0].device.key = -100
$spec.deviceChange[0].device.backing = New-Object VMware.Vim.VirtualDiskRawDiskMappingVer1BackingInfo
$spec.deviceChange[0].device.backing.fileName = ""
$spec.deviceChange[0].device.backing.deviceName = "/vmfs/devices/disks/naa.60a980006471682f536f684f6669706a"
$spec.deviceChange[0].device.backing.compatibilityMode = "physicalMode"
$spec.deviceChange[0].device.backing.diskMode = ""
$spec.deviceChange[0].device.connectable = New-Object VMware.Vim.VirtualDeviceConnectInfo
$spec.deviceChange[0].device.connectable.startConnected = $true
$spec.deviceChange[0].device.connectable.allowGuestControl = $false
$spec.deviceChange[0].device.connectable.connected = $true
$spec.deviceChange[0].device.controllerKey = 1000
$spec.deviceChange[0].device.unitNumber = 3
$spec.deviceChange[0].device.capacityInKB = 10490445
$_this = Get-View -Id 'VirtualMachine-vm-314942'
$_this.ReconfigVM_Task($spec)

# Yeni bir SCSI Controller ile RDM ekleme, Controller tipini deðiþtirmeden
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.changeVersion = "2012-08-07T08:41:09.509762Z"
$spec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec[] (2)
$spec.deviceChange[0] = New-Object VMware.Vim.VirtualDeviceConfigSpec
$spec.deviceChange[0].operation = "add"
$spec.deviceChange[0].fileOperation = "create"
$spec.deviceChange[0].device = New-Object VMware.Vim.VirtualDisk
$spec.deviceChange[0].device.key = -100
$spec.deviceChange[0].device.backing = New-Object VMware.Vim.VirtualDiskRawDiskMappingVer1BackingInfo
$spec.deviceChange[0].device.backing.fileName = ""
$spec.deviceChange[0].device.backing.deviceName = "/vmfs/devices/disks/naa.60a980006471682f536f684f6669706a"
$spec.deviceChange[0].device.backing.compatibilityMode = "physicalMode"
$spec.deviceChange[0].device.backing.diskMode = ""
$spec.deviceChange[0].device.connectable = New-Object VMware.Vim.VirtualDeviceConnectInfo
$spec.deviceChange[0].device.connectable.startConnected = $true
$spec.deviceChange[0].device.connectable.allowGuestControl = $false
$spec.deviceChange[0].device.connectable.connected = $true
$spec.deviceChange[0].device.controllerKey = -101
$spec.deviceChange[0].device.unitNumber = 1
$spec.deviceChange[0].device.capacityInKB = 10490445
$spec.deviceChange[1] = New-Object VMware.Vim.VirtualDeviceConfigSpec
$spec.deviceChange[1].operation = "add"
$spec.deviceChange[1].device = New-Object VMware.Vim.VirtualLsiLogicController
$spec.deviceChange[1].device.key = -101
$spec.deviceChange[1].device.controllerKey = 100
$spec.deviceChange[1].device.busNumber = 1
$spec.deviceChange[1].device.sharedBus = "noSharing"
$_this = Get-View -Id 'VirtualMachine-vm-314942'
$_this.ReconfigVM_Task($spec)

# Yeni bir SCSI Controller ile RDM ekleme, Controller tipi SAS
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.changeVersion = "2012-08-07T08:46:57.930754Z"
$spec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec[] (2)
$spec.deviceChange[0] = New-Object VMware.Vim.VirtualDeviceConfigSpec
$spec.deviceChange[0].operation = "add"
$spec.deviceChange[0].fileOperation = "create"
$spec.deviceChange[0].device = New-Object VMware.Vim.VirtualDisk
$spec.deviceChange[0].device.key = -100
$spec.deviceChange[0].device.backing = New-Object VMware.Vim.VirtualDiskRawDiskMappingVer1BackingInfo
$spec.deviceChange[0].device.backing.fileName = ""
$spec.deviceChange[0].device.backing.deviceName = "/vmfs/devices/disks/naa.60a980006471682f536f684f6669706a"
$spec.deviceChange[0].device.backing.compatibilityMode = "physicalMode"
$spec.deviceChange[0].device.backing.diskMode = ""
$spec.deviceChange[0].device.connectable = New-Object VMware.Vim.VirtualDeviceConnectInfo
$spec.deviceChange[0].device.connectable.startConnected = $true
$spec.deviceChange[0].device.connectable.allowGuestControl = $false
$spec.deviceChange[0].device.connectable.connected = $true
$spec.deviceChange[0].device.controllerKey = -101
$spec.deviceChange[0].device.unitNumber = 0
$spec.deviceChange[0].device.capacityInKB = 10490445
$spec.deviceChange[1] = New-Object VMware.Vim.VirtualDeviceConfigSpec
$spec.deviceChange[1].operation = "add"
$spec.deviceChange[1].device = New-Object VMware.Vim.VirtualLsiLogicSASController
$spec.deviceChange[1].device.key = -101
$spec.deviceChange[1].device.controllerKey = 100
$spec.deviceChange[1].device.busNumber = 1
$spec.deviceChange[1].device.sharedBus = "noSharing"
$_this = Get-View -Id 'VirtualMachine-vm-314942'
$_this.ReconfigVM_Task($spec)







