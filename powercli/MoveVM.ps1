param ( [Parameter(Mandatory=$true)] [string]$vmname,
		[Switch]$DryRun = $false )

Function xMove-VM {
    param(
    [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [VMware.VimAutomation.ViCore.Util10.VersionedObjectImpl]$sourcevc,
    [VMware.VimAutomation.ViCore.Util10.VersionedObjectImpl]$destvc,
    [String]$vm,
    [String]$switchtype,
    [String]$switch,
    [String]$cluster,
    [String]$resourcepool,
    [String]$datastore,
    [String]$vmhost,
    [String]$vmnetworks,
    [Int]$xvctype,
    [Boolean]$uppercaseuuid
    )

    # Retrieve Source VC SSL Thumbprint
    $vcurl = "https://" + $destVC
add-type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
            public class IDontCarePolicy : ICertificatePolicy {
            public IDontCarePolicy() {}
            public bool CheckValidationResult(
                ServicePoint sPoint, X509Certificate cert,
                WebRequest wRequest, int certProb) {
                return true;
            }
        }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = new-object IDontCarePolicy
    # Need to do simple GET connection for this method to work
    Invoke-RestMethod -Uri $VCURL -Method Get | Out-Null

    $endpoint_request = [System.Net.Webrequest]::Create("$vcurl")
    # Get Thumbprint + add colons for a valid Thumbprint
    $destVCThumbprint = ($endpoint_request.ServicePoint.Certificate.GetCertHashString()) -replace '(..(?!$))','$1:'

    # Source VM to migrate
    $vm_view = Get-View (Get-VM -Server $sourcevc -Name $vm) -Property Config.Hardware.Device

    # Dest Datastore to migrate VM to
    $datastore_view = (Get-Datastore -Server $destVCConn -Name $datastore)

    # Dest Cluster/ResourcePool to migrate VM to
    if($cluster) {
        $cluster_view = (Get-Cluster -Server $destVCConn -Name $cluster)
        $resource = $cluster_view.ExtensionData.resourcePool
    } else {
        $rp_view = (Get-ResourcePool -Server $destVCConn -Name $resourcepool)
        $resource = $rp_view.ExtensionData.MoRef
    }

    # Dest ESXi host to migrate VM to
    $vmhost_view = (Get-VMHost -Server $destVCConn -Name $vmhost)

    # Find all Etherenet Devices for given VM which
    # we will need to change its network at the destination
    $vmNetworkAdapters = @()
    $devices = $vm_view.Config.Hardware.Device
    foreach ($device in $devices) {
        if($device -is [VMware.Vim.VirtualEthernetCard]) {
            $vmNetworkAdapters += $device
        }
    }

    # Relocate Spec for Migration
    $spec = New-Object VMware.Vim.VirtualMachineRelocateSpec
    $spec.datastore = $datastore_view.Id
    $spec.host = $vmhost_view.Id
    $spec.pool = $resource

    # Relocate Spec Disk Locator
    if($xvctype -eq 1){
        $HDs = Get-VM -Server $sourcevc -Name $vm | Get-HardDisk
        $HDs | %{
            $disk = New-Object VMware.Vim.VirtualMachineRelocateSpecDiskLocator
            $disk.diskId = $_.Extensiondata.Key
            $SourceDS = $_.FileName.Split("]")[0].TrimStart("[")
            $DestDS = Get-Datastore -Server $destvc -name $sourceDS
            $disk.Datastore = $DestDS.ID
            $spec.disk += $disk
        }
    }

    # Service Locator for the destination vCenter Server
    # regardless if its within same SSO Domain or not
    $service = New-Object VMware.Vim.ServiceLocator
    $credential = New-Object VMware.Vim.ServiceLocatorNamePassword
    $credential.username = $destVCusername
    $credential.password = $destVCpassword
    $service.credential = $credential
    # For some xVC-vMotion, VC's InstanceUUID must be in all caps
    # Haven't figured out why, but this flag would allow user to toggle (default=false)
    if($uppercaseuuid) {
        $service.instanceUuid = $destVCConn.InstanceUuid
    } else {
        $service.instanceUuid = ($destVCConn.InstanceUuid).ToUpper()
    }
    $service.sslThumbprint = $destVCThumbprint
    $service.url = "https://$destVC"
    $spec.service = $service

    # Create VM spec depending if destination networking
    # is using Distributed Virtual Switch (VDS) or
    # is using Virtual Standard Switch (VSS)
    $count = 0
    if($switchtype -eq "vds") {
        foreach ($vmNetworkAdapter in $vmNetworkAdapters) {
            # New VM Network to assign vNIC
            $vmnetworkname = ($vmnetworks -split ",")[$count]

            # Extract Distributed Portgroup required info
            $dvpg = Get-VDPortgroup -Server $destvc -Name $vmnetworkname
            $vds_uuid = (Get-View $dvpg.ExtensionData.Config.DistributedVirtualSwitch).Uuid
            $dvpg_key = $dvpg.ExtensionData.Config.key

            # Device Change spec for VSS portgroup
            $dev = New-Object VMware.Vim.VirtualDeviceConfigSpec
            $dev.Operation = "edit"
            $dev.Device = $vmNetworkAdapter
            $dev.device.Backing = New-Object VMware.Vim.VirtualEthernetCardDistributedVirtualPortBackingInfo
            $dev.device.backing.port = New-Object VMware.Vim.DistributedVirtualSwitchPortConnection
            $dev.device.backing.port.switchUuid = $vds_uuid
            $dev.device.backing.port.portgroupKey = $dvpg_key
            $spec.DeviceChange += $dev
            $count++
        }
    } else {
        # foreach ($vmNetworkAdapter in $vmNetworkAdapters) {
            # # New VM Network to assign vNIC
            # $vmnetworkname = ($vmnetworks -split ",")[$count]

            # # Device Change spec for VSS portgroup
            # $dev = New-Object VMware.Vim.VirtualDeviceConfigSpec
            # $dev.Operation = "edit"
            # $dev.Device = $vmNetworkAdapter
            # $dev.device.backing = New-Object VMware.Vim.VirtualEthernetCardNetworkBackingInfo
            # $dev.device.backing.deviceName = $vmnetworkname
            # $spec.DeviceChange += $dev
            # $count++
        # }
    }

    # Issue Cross VC-vMotion
    $task = $vm_view.RelocateVM_Task($spec,"defaultPriority")
    $task1 = Get-Task -Id ("Task-$($task.value)")
    $task1 | Wait-Task
}

# Variables that must be defined



$sourceVC = ""
$sourceVCUsername = ""
$sourceVCPassword = ""
$destVC = ""
$destVCUsername = ""
$destVCpassword = ""
$resourcepool = ""
$vmhostname = ""
$switchname = ""
$switchtype = "vds"
$ComputeXVC = 1
$UppercaseUUID = $true

$vmnetworkname = $null

# Connect to Source/Destination vCenter Server
$sourceVCConn = Connect-VIServer -Server $sourceVC -user $sourceVCUsername -password $sourceVCPassword
	$VM = Get-VM -Name $vmname -Server $sourceVCConn
	$VM_view = Get-View $VM -Property Config.Hardware.Device
	$Folder = Get-Folder -Id ("Folder-{0}" -f $VM.ExtensionData.Parent.Value)
	$foldername = $Folder.Name
	$datastorename = $VM.ExtensionData.Config.Files.VmPathName.Substring(1,17)
	$devices = $VM_view.Config.Hardware.Device
    foreach ($device in $devices) {
        if($device -is [VMware.Vim.VirtualEthernetCard]) {
			$sourcePG = Get-VDPortgroup -Id ("DistributedVirtualPortgroup-{0}" -f $device.Backing.Port.PortgroupKey) -Server $sourceVCConn
			$sourcePG_split = $sourcePG.Name.Split(".")
			$destPG_string = ("Dvp.{0}.{1}" -f $sourcePG_split[2],$sourcePG_split[3])
			if ($vmnetworkname.count -ge 1) {$vmnetworkname += ","}
			$vmnetworkname += $destPG_string
        }
    }

$destVCConn = Connect-VIServer -Server $destVC -user $destVCUsername -password $destVCpassword

if ($DryRun) { Write-Host "`n------Dry Run------" -ForegroundColor Cyan }
	else { Write-Host "`n--------------Production Run--------------" -ForegroundColor Cyan }
Write-Host "$vmname on DS: [$datastorename]"
Write-Host "Folder Name: $foldername"
Write-Host "Network Labels: $vmnetworkname `n"

if ($VM.ExtensionData.Guest.HostName) {
	Write-Host "Ping Test before migration: " -NoNewLine
	if ($PingResult = Test-Connection -ComputerName $VM.ExtensionData.Guest.HostName -Count 1 -Quiet) {
		Write-Host $PingResult.ToString().ToUpper() -ForeGroundColor GREEN
	} else {
		Write-Host $PingResult.ToString().ToUpper() -ForeGroundColor RED
	}
} else {
	Write-Host "Hostname cannot be found for this VM, skipping ping test"
}

if (!$DryRun) {
	xMove-VM -sourcevc $sourceVCConn -destvc $destVCConn -VM $vmname -switchtype $switchtype -switch $switchname -resourcepool $resourcepool -vmhost $vmhostname -datastore $datastorename -vmnetwork  $vmnetworkname -xvcType $computeXVC -uppercaseuuid $UppercaseUUID
	Move-VM -VM $vmname -Destination (Get-Folder -Name $foldername) -Confirm:$false
	Start-Sleep -Seconds 5
}

if ($VM.ExtensionData.Guest.HostName) {
	Write-Host "Ping Test after migration : " -NoNewLine
	if ($PingResult = Test-Connection -ComputerName $VM.ExtensionData.Guest.HostName -Count 1 -Quiet) {
		Write-Host $PingResult.ToString().ToUpper() -ForeGroundColor GREEN
	} else {
		Write-Host $PingResult.ToString().ToUpper() -ForeGroundColor RED
	}
} else {
	Write-Host "Hostname cannot be found for this VM, skipping ping test"
}

# Disconnect from Source/Destination VC
Disconnect-VIServer -Server $sourceVCConn -Confirm:$false
Disconnect-VIServer -Server $destVCConn -Confirm:$false