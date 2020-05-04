# *********************************************************************
#
# Powershell script that deletes snapshots older than defined days
#
# USAGE: ./Remove-BulkSnapshot.ps1 -Retention <NumberOfDays>
#
# ASSUMPTIONS:
#
# *********************************************************************

param([Parameter(Mandatory=$true)][int32]$Retention)

function DeleteOldSnapshots {
	param([int32]$DaysToDelete)

	$SnapshotsToDelete = @()
	$VMs = Get-VM
	$Today = Get-Date

	foreach ($VM in $VMs) {
		Clear-Host
		Write-Host ("Working on {0}" -f $VM.Name) 
		$Snapshots = Get-Snapshot -VM $VM
		if (!$Snapshots) { continue }
		
		foreach ($Snapshot in $Snapshots) {
			$SnapshotCreateDate = $Snapshot.Created
			$DaysOld = $Today.Subtract($SnapshotCreateDate).Days
			if ($DaysOld -gt $DaysToDelete) { $SnapshotsToDelete += $Snapshot }			
		}
	}
	
	Clear-Host
	$SnapshotsToDelete = $SnapshotsToDelete | Sort-Object -Property $SnapshotsToDelete.Created
	
	foreach ($SnapshotToDelete in $SnapshotsToDelete) {
		Write-Host ("Remove-Snapshot -Snapshot {0} -RunAsync -Confirm:$false" -f $SnapshotToDelete)
		# Remove-Snapshot -Snapshot $SnapshotToDelete -RunAsync -Confirm:$false
	}
}

# ************* MAIN SUB **********************************************

$Credential = Get-VICredentialStoreItem -File D:\Library\Tools\Credentials\Cred-VCENTER.xml
$VCenters = ("")
  
foreach ($VCenter in $VCenters) {
	Connect-VIServer -Server $VCenter -User $Credential.User -Password $Credential.Password
	DeleteOldSnapshots -DaysToDelete $Retention
	Disconnect-VIServer -Confirm:$False
}
