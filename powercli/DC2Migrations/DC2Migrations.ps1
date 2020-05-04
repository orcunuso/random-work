# Project     : Bulk Storage vMotion
# Prepared by : Ozan Orçunus
# Create Date : 30.01.2013
# Modify Date : 06.02.2013

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)][string]$VolumeName )

function InitializeEnvironment {
	Import-Module -Name ModING -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "DC2Migrations"
}

function UninitializeEnvironment {
	Uninitialize-INGScript
	Disconnect-VIServer -Confirm:$false
}

function CheckCDDrive {
	param ([VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]$VM)
	
	$objCD = Get-CDDrive -VM $VM | Where-Object { $_.IsoPath.Length -gt 0 -OR $_.HostDevice.Length -gt 0 }
	if ($objCD) {
		Write-INGLog -Message ("CD-ROM mounted. Unmounting")
		try { Set-CDDrive -CD $objCD -NoMedia -Confirm:$False | Out-Null } 
			catch [System.Exception] { Write-INGLog ("   EXCEPTION: " + $_.Exception.Message) }
	} else {
		Write-INGLog -Message ("CD-ROM is not mounted")
	}
}

function FindTargetDatastore {
	param ([VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]$VM)
	
	$ExcelFile    = "C:\Scripts\DC2Migrations\VMCONTINUITY.xlsx"
	$ExcelSheet   = "VMs"
	$OleDbConn    = New-Object "System.Data.OleDb.OleDbConnection"
	$OleDbCmd     = New-Object "System.Data.OleDb.OleDbCommand"
	$OleDbAdapter = New-Object "System.Data.OleDb.OleDbDataAdapter"
	$Table        = New-Object "System.Data.DataTable"
	
	$VM = Get-VM -Name "DC2VM"

	$OleDbConn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$ExcelFile;Extended Properties=""Excel 12.0 Xml;HDR=YES"";"
	$OleDbConn.Open()
	$OleDbCmd.Connection = $OleDbConn
	$OleDbCmd.CommandText = ("Select * from [{0}$] Where Name='{1}'" -f $ExcelSheet, $VM.Name)
	$OleDbAdapter.SelectCommand = $OleDbCmd
	$RowsReturned = $OleDbAdapter.Fill($Table)
	$OleDbConn.Close()
	
	if ($Table.Rows.Count -eq 1) { $VMContinuity = $Table.Rows[0].Continuity }
		else { 
			Write-INGLog -Message ("{0} cannot be found in the continuity file" -f $VM.Name) -Severity ERROR 
			$VMContinuity = "Unidentified"
		}
	
	if ($VMContinuity -eq "STR: SnapMirror") { $Datastore_Part1 = "DS.BDC" }
		else { $Datastore_Part1 = "DS.LOC" }
	
	switch ($VM.Host.Parent.Name) {
		"RSFBB"		{ $Datastore_Part2 = "RSFBB" }
		"MTBB"		{ $Datastore_Part2 = "RSFBB" }
		"eDMZBB"	{ $Datastore_Part2 = "DMZBB" }
		"iDMZBB"	{ $Datastore_Part2 = "DMZBB" }
		default		{ $Datastore_Part2 = "" }
	}
	
	
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

InitializeEnvironment

$ExcelFile    = "C:\Scripts\DC2Migrations\VMINFO.xlsx"
$ExcelSheet   = "VM-Devices"
$OleDbConn    = New-Object "System.Data.OleDb.OleDbConnection"
$OleDbCmd     = New-Object "System.Data.OleDb.OleDbCommand"
$OleDbAdapter = New-Object "System.Data.OleDb.OleDbDataAdapter"
$Table        = New-Object "System.Data.DataTable"

$VolumeName = "VM_DC2_DS_2A_01"

$OleDbConn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$ExcelFile;Extended Properties=""Excel 12.0 Xml;HDR=YES"";"
$OleDbConn.Open()
$OleDbCmd.Connection = $OleDbConn
$OleDbCmd.CommandText = ("Select * from [{0}$] Where Volume='{1}'" -f $ExcelSheet, $VolumeName)
$OleDbAdapter.SelectCommand = $OleDbCmd
$RowsReturned = $OleDbAdapter.Fill($Table)
$OleDbConn.Close()

$Datastores = @()

foreach ($TableRow in $Table.Rows) {
	if (!($TableRow.DatastoreName -match "TESTNDEV")) {
		$Datastores += $TableRow.DatastoreName
	}
}

$VMs = Get-Datastore -Name $Datastores | Get-VM

foreach ($VM in $VMs) {

	if ((Get-Content -Path $Global:CtrlFile) -eq "STOP") { 
		Write-INGLog ("*********** Script terminated by user input!!!") "WARNING"
		break 
	}
	
	Write-INGLog -Message "---" + $VM.Name + "---" -Severity INFO
	CheckCDDrive -VM $VM
	
	$TargetDatastore = FindTargetDatastore -VM $VM
	Move-VM -VM $VM -Datastore $TargetDatastore -Confirm:$false
}

UninitializeEnvironment































# [MAIN] ...................................................................................

$Global:ScrPath   = "D:\Library\Scripts\Powershell\VM\MoveStorage\"
$Global:LogFile   = $Global:ScrPath + "MoveStorage-VMs-DC2.log"
$Global:CsvFile   = $Global:ScrPath + "MoveStorage-VMs-DC2.csv"
$Global:CtrlFile  = $Global:ScrPath + "MoveStorage-VMs-DC2.control"
$CSVLines         = Import-Csv $Global:CsvFile
$TimeToStop       = Get-Date -Year (Get-Date).Year -Month (Get-Date).Month -Day (Get-Date).Day -Hour 17 -Minute 10 -Second 0
$index            = 0
$MaxTaskCount     = 2

WriteLog ("********** Script started **********")

while ($index -lt $CSVLines.Count) {

	$CSVLine        = $CSVLines[$index]
	$RunningTasks   = Get-Task -Status Running | Where { $_.Name -eq "RelocateVM_Task" }
	$TimeCompleted  = ((Get-Date) -gt $TimeToStop)
	$ManualStop     = Get-Content -Path $Global:CtrlFile
	
	if ($TimeCompleted -or ($ManualStop -eq "STOP")) { WriteLog ("Enough for today, see you tomorrow :)"); break }
	if (($CSVLine.Status -eq "PASS") -or ($CSVLine.Status -eq "STARTED")) { $index++; continue }
	
	if ($RunningTasks.Count -ge $MaxTaskCount) { 
		WriteLog ("Running task count: " + $RunningTasks.Count + ". Sleeping for 2 minutes")
		Start-Sleep -Seconds 120; continue 
	}
	
	WriteLog ($CSVLine.Name)
	
	$VM = Get-VM -Name $CSVLine.Name
	Write-Host $VM.Name
	if (!$VM) { $CSVLine.Status = "NOTFOUND"; WriteLog ("   VM not found"); $index++; continue } 
	
	if (CheckSnapshot $CSVLine.Name) { $CSVLine.Status = "SNAPSHOT"; WriteLog ("   Snapshot found"); $index++; continue }
	CheckCDDrive $VM

	$SourceDS = $VM.ExtensionData.Config.DatastoreUrl[0].Name
	if (!($SourceDS.Contains(".1A")) -and !($SourceDS.Contains(".1B"))) {
		$CSVLine.Status = "NOTFOUND"
		WriteLog ("   VM found in " + $SourceDS + " Skipping")
		$index++; continue
	}
	
	$TargetDS = FindTargetDatastore $SourceDS
	WriteLog ("   SvMotion started for " + $CSVLine.Name + " from " + $SourceDS + " to " + $TargetDS )
	Move-VM -VM $VM -Datastore $TargetDS -RunAsync -Confirm:$false | Out-Null
	$CSVLine.Status = "STARTED"
	$index++
	
	Start-Sleep -Seconds 60
}

$CSVLines | Export-Csv -NoTypeInformation -Path $Global:CsvFile

WriteLog ("********** Script completed **********")

# [END] ....................................................................................














