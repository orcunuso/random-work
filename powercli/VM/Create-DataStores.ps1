$ExcelFile  = "D:\Business\Documents\a.xlsx"
$ExcelSheet = "a"

$OleDbConn    = New-Object "System.Data.OleDb.OleDbConnection"
$OleDbCmd     = New-Object "System.Data.OleDb.OleDbCommand"
$OleDbAdapter = New-Object "System.Data.OleDb.OleDbDataAdapter"
$DataTable    = New-Object "System.Data.DataTable"

$OleDbConn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$ExcelFile;Extended Properties=""Excel 12.0 Xml;HDR=YES"";"
$OleDbConn.Open()

$OleDbCmd.Connection = $OleDbConn
$OleDbCmd.commandtext = "Select * from [$ExcelSheet$]"
$OleDbAdapter.SelectCommand = $OleDbCmd

$RowsReturned = $OleDbAdapter.Fill($DataTable)

ForEach ($ESXHost in $DataTable | Select ESXHost -Unique) {

	$ESX = Get-VMHost $ESXHost.ESXHost | Get-View
	$StorSys = Get-View $ESX.ConfigManager.StorageSystem

	ForEach ($DS in $DataTable | Where {$_.ESXHost -eq $ESXHost.ESXHost}) {
		#Write-host $ESXHost.ESXHost `t $DS.DataStoreName `t $DS.DeviceID
		
		#Select LUN
		$Lun = $ESX.Config.StorageDevice.ScsiLun | Where {$_.CanonicalName -eq $DS.DeviceID}
		
		#Change LUN DisplayName
		$StorSys.UpdateScsiLunDisplayName($Lun.Uuid, $DS.DeviceName)

		#Create DataStore
		New-DataStore -Name $DS.DatastoreName -Path $DS.DeviceID -Vmfs -BlockSizeMB 1 -VMHost $ESXHost.ESXHost
		
		#Rename DataStore
		#Get-Datastore -Name $DSName | Set-Datastore -Name $NewDSName		
	}
}

$OleDbConn.Close()