# Project     : Automated Storage Migrations
# Prepared by : Ozan Orçunus
# Create Date : 26.09.2013
# Modify Date : 23.10.2013
#

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$false)][string]$DC2Cluster,
		[Parameter(Mandatory=$true)][string]$vCenter, 
		[Parameter(Mandatory=$true)][string]$Start,
		[Parameter(Mandatory=$true)][string]$Stop )

function InitializeEnvironment {
	Import-Module -Name ModING -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "StorageMigrations"
	Connect-INGvCenter -vCenter $vCenter
}

function UninitializeEnvironment {
	Uninitialize-INGScript
	Disconnect-INGvCenter -vCenter $vCenter
}

function UpdateTableRow {
	param ([String]$UpdateField, [String]$UpdateValue, [String]$VirtualMachineName)
	$ExcelSheet   = "StorageMigrations"
	$OleDbConn    = New-Object "System.Data.OleDb.OleDbConnection"
	$OleDbCmd     = New-Object "System.Data.OleDb.OleDbCommand"
	$OleDbConn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$Global:XlsFile;Extended Properties=""Excel 12.0 Xml;HDR=YES"";"
	$OleDbConn.Open()
	$OleDbCmd.Connection = $OleDbConn
	$OleDbCmd.CommandText = ("Update [{0}$] Set {1}='{2}' Where Name='{3}'" -f $ExcelSheet,$UpdateField,$UpdateValue,$VirtualMachineName)
	$OleDbCmd.ExecuteNonQuery() | Out-Null
	$OleDbConn.Close()
}

function IsDatastoreAvailable {
	param ( [VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl]$DS,
			[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]$VM )
	
	$VMSize = 0
	$Disks  = Get-HardDisk -VM $VM -DiskType "Flat"
	foreach ($Disk in $Disks) { $VMSize += [int]$Disk.CapacityKB / (1024 * 1024) }
	
	$AcceptCapacity = [int]$DS.CapacityMB / 1024 * 0.08
	$RemainCapacity = [int]($DS.FreeSpaceMB / 1024) - $VMSize
	Write-INGLog -Message ("VM Size for {0}: {1}" -f $VM.Name, $VMSize)
	Write-INGLog -Message ("Remaining capacity for {0}: {1}" -f $DS.Name, $RemainCapacity)
	
	if ($RemainCapacity -gt $AcceptCapacity) { return $true }
		else { return $false }
}

function Convert-DateString ([String]$Date, [String[]]$Format)
{
   $convertible = [DateTime]::ParseExact($Date,$Format,[System.Globalization.CultureInfo]::InvariantCulture) 
   if ($convertible) { $result }
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

InitializeEnvironment

$ExcelSheet   = "StorageMigrations"
$OleDbConn    = New-Object "System.Data.OleDb.OleDbConnection"
$OleDbCmd     = New-Object "System.Data.OleDb.OleDbCommand"
$OleDbAdapter = New-Object "System.Data.OleDb.OleDbDataAdapter"
$Table        = New-Object "System.Data.DataTable"

$OleDbConn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$Global:XlsFile;Extended Properties=""Excel 12.0 Xml;HDR=YES"";"
$OleDbConn.Open()
$OleDbCmd.Connection = $OleDbConn
$OleDbCmd.CommandText = ("Select * from [{0}$] Where Status='NotStarted'" -f $ExcelSheet)
$OleDbAdapter.SelectCommand = $OleDbCmd
$RowsReturned = $OleDbAdapter.Fill($Table)
$OleDbConn.Close()

$TimeToStart = [DateTime]::ParseExact($Start,"dd.MM.yyyy HH:mm",[System.Globalization.CultureInfo]::InvariantCulture,[System.Globalization.DateTimeStyles]::None)
$TimeToStop  = [DateTime]::ParseExact($Stop ,"dd.MM.yyyy HH:mm",[System.Globalization.CultureInfo]::InvariantCulture,[System.Globalization.DateTimeStyles]::None)
Write-INGLog -Message ("Script will start at <{0}> and stop at <{1}>" -f $TimeToStart.toString(), $TimeToStop.toString()) -Severity "INFO"

do {
	$DateKontrol = Get-Date
	if (($DateKontrol.Day -eq $TimeToStart.Day) -and ($DateKontrol.Hour -eq $TimeToStart.Hour) -and ($DateKontrol.Minute -ge $TimeToStart.Minute)) { break }
	Write-INGLog -Message ("Waiting for start time... Looping")
	Start-Sleep -Seconds 600
} while ($true)

foreach ($TableRow in $Table.Rows) {
	
	$UserStop = Get-Content -Path $Global:CtrlFile
	$TimeStop = ((Get-Date) -gt $TimeToStop)
	if ($TimeStop)            { Write-INGLog -Message ("Enough for today, see you tomorrow :)") -Severity "INFO"; break }
	if ($UserStop -eq "STOP") { Write-INGLog -Message ("Script terminated by user input") -Severity "INFO";       break }

	Write-INGLog -Message ("<-- Migrating VM {0} -->" -f $TableRow.Name) -Severity "INFO"
	UpdateTableRow -UpdateField "Status" -UpdateValue "Started" -VirtualMachineName $TableRow.Name
	
	$VM = $null
	$VM = Get-VM -Name $TableRow.Name -ErrorAction:SilentlyContinue
	if (!$VM) {
		Write-INGLog -Message ("{0} cannot be found in the inventory: {1}" -f $TableRow.Name, $vCenter) -Severity "WARNING"
		UpdateTableRow -UpdateField "Status" -UpdateValue "NotCompleted (VM)" -VirtualMachineName $TableRow.Name
		Start-Sleep -Seconds 10
		continue
	}
	
	$Datastore = Get-Datastore -Name $TableRow.NewDatastore
	if ((IsDatastoreAvailable -DS $Datastore -VM $VM) -eq $false) { 
		Write-INGLog -Message ("Not enough store on {0}" -f $Datastore.Name) -Severity "WARNING"
		UpdateTableRow -UpdateField "Status" -UpdateValue "NotCompleted (DS)" -VirtualMachineName $TableRow.Name
		continue
	}
	
	try {
		Move-VM -VM $VM -Datastore $Datastore -Confirm:$false | Out-Null
		Write-INGLog -Message "Storage vMotion complited"
		UpdateTableRow -UpdateField "Status" -UpdateValue "Completed" -VirtualMachineName $TableRow.Name
	}
		catch [System.Exception] {
			Write-INGLog -Message ("EXCEPTION: " + $_.Exception.Message) -Severity "ERROR"
			UpdateTableRow -UpdateField "Status" -UpdateValue "Error" -VirtualMachineName $TableRow.Name
		}
	
	Start-Sleep -Seconds 15
}

UninitializeEnvironment

# [END] ....................................................................................














