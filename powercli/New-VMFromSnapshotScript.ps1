function New-VMFromSnapshotOriginal {
	[CmdletBinding()]
	Param ( [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$SourceVMName,
			[parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$CloneName,
			[parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$SnapshotName,
			[parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][String]$ClusterName,
			[parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][String]$DatastoreName,
			[parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][String]$FolderName,
			[parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][Switch]$LinkedClone
	)
	
	function Test-SnapshotExists ($SnapshotQuery) {
		try {
			Write-Verbose "Test ediliyor $SnapshotQuery....`n"
			$TestSnapshot = Invoke-Expression $SnapshotQuery
			Write-Output $TestSnapshot
		} catch [Exception] {
			$TestSnapshot = $false
			Write-Output $TestSnapshot
		}
	}
	
	$SourceVM = Get-VM -Name $SourceVMName -ErrorAction:SilentlyContinue
	if ($SourceVM) {
		$ResourcePoolMoRef = (Get-Cluster -Name $ClusterName | Get-ResourcePool -Name "Resources").ExtensionData.MoRef
		$DatastoreMoRef = (Get-Datastore -Name $DatastoreName).ExtensionData.MoRef
		$FolderMoRef = (Get-Folder -Name $FolderName -Type VM -ErrorAction:SilentlyContinue).ExtensionData.MoRef
		if (!$FolderMoRef) {  
			Write-Host ("{0} klasoru bulunamadi, kaynak VM ile ayni klasor kullanilacak" -f $FolderName)
			$FolderMoRef = $SourceVM.ExtensionData.Parent
		}
		if ($LinkedClone) { $CloneType = "createNewChildDiskBacking" }
			else { $CloneType = "moveAllDiskBackingsAndDisallowSharing" }
			
		$Snapshots = @()
		$SnapshotQuery = '$SourceVM.ExtensionData.Snapshot.RootSnapshotList[0]'
		while ($Snapshot = Test-SnapshotExists -SnapshotQuery $SnapshotQuery) {
			$SnapshotQuery += '.ChildSnapshotList[0]'
			$Snapshots += $Snapshot
		}
		
		$CloneSpec = New-Object Vmware.Vim.VirtualMachineCloneSpec
		$CloneSpec.Snapshot = ($Snapshots | Where-Object {$_.Name -eq $SnapshotName}).Snapshot
		$CloneSpec.Location = New-Object Vmware.Vim.VirtualMachineRelocateSpec
		$CloneSpec.Location.Pool = $ResourcePoolMoRef
		$CloneSpec.Location.Datastore = $DatastoreMoRef
		$CloneSpec.Location.DiskMoveType = [Vmware.Vim.VirtualMachineRelocateDiskMoveOptions]::$CloneType
		$VITask = $SourceVM.ExtensionData.CloneVM_Task($FolderMoRef, $CloneName, $CloneSpec)
			
	} else {
		Write-Host ("{0} sanal sunucusu bulunamadi" -f $SourceVMName) -ForeGroundColor Red 
	}
}

function CreateVMFromSnap {
	[CmdletBinding()]
	Param ( [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$SourceVMName,
			[parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$CloneName,
			[parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$SnapshotName,
			[parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$ClusterName,
			[parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$DatastoreName,
			[parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$FolderName,
			[parameter(Mandatory=$false)][Switch]$LinkedClone
	)
	
	$SourceVM = Get-VM -Name $SourceVMName -ErrorAction:SilentlyContinue
	if ($SourceVM) {
		$Snapshots = Get-Snapshot -VM $SourceVM
		$ResourcePoolMoRef = (Get-Cluster -Name $ClusterName | Get-ResourcePool -Name "Resources").ExtensionData.MoRef
		$DatastoreMoRef = (Get-Datastore -Name $DatastoreName).ExtensionData.MoRef
		$FolderMoRef = (Get-Folder -Name $FolderName -Type VM).ExtensionData.MoRef
		if ($LinkedClone) { $CloneType = "createNewChildDiskBacking" }
			else { $CloneType = "moveAllDiskBackingsAndDisallowSharing" }
		
		$CloneSpec = New-Object Vmware.Vim.VirtualMachineCloneSpec
		$CloneSpec.Snapshot = ($Snapshots | Where-Object {$_.Name -eq $SnapshotName}).ExtensionData.Snapshot
		$CloneSpec.Location = New-Object Vmware.Vim.VirtualMachineRelocateSpec
		$CloneSpec.Location.Pool = $ResourcePoolMoRef
		$CloneSpec.Location.Datastore = $DatastoreMoRef
		$CloneSpec.Location.DiskMoveType = [Vmware.Vim.VirtualMachineRelocateDiskMoveOptions]::$CloneType
		$VITask = $SourceVM.ExtensionData.CloneVM_Task($FolderMoRef, $CloneName, $CloneSpec)
			
	} else {
		Write-Host ("{0} sanal sunucusu bulunamadi" -f $SourceVMName) -ForeGroundColor Red 
	}
}

# CreateVMFromSnap -SourceVMName PHOTON02 -CloneName PHOTON03 -SnapshotName VMX10_Kapali -ClusterName DC2.DemoCluster -DatastoreName Datastore02 -FolderName VMFolder

for ($num=3; $num -le 10; $num++) {
	CreateVMFromSnap -SourceVMName PHOTON02 -CloneName ("PHOTON{0}" -f $num) -SnapshotName VMX10_Acik_Belleksiz -ClusterName DC2.DemoCluster -DatastoreName Datastore02 -FolderName VMFolder -LinkedClone
	#Start-VM -VM ("PHOTON{0}" -f $num)
}