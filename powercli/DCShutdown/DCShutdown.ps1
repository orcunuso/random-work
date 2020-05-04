# Project     : Automated VM Shutdown
# Prepared by : Ozan Orçunus
#

# [FUNCTIONS - General] ===================================================================

param ( [Parameter(Mandatory=$true)][string]$vCenter,
		[Parameter(Mandatory=$true)][int]$Order,
		[Switch]$ShutDownControl )

function InitializeEnvironment {
	Import-Module -Name ModING -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "DCShutdown"
	Connect-INGvCenter -vCenter $vCenter
}

function UninitializeEnvironment {
	Uninitialize-INGScript
	Disconnect-INGvCenter -vCenter $vCenter
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

InitializeEnvironment

$ExcelSheet   = $Global:ScrptName
$OleDbConn    = New-Object "System.Data.OleDb.OleDbConnection"
$OleDbCmd     = New-Object "System.Data.OleDb.OleDbCommand"
$OleDbAdapter = New-Object "System.Data.OleDb.OleDbDataAdapter"
$Table        = New-Object "System.Data.DataTable"

$OleDbConn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$Global:XlsFile;Extended Properties=""Excel 12.0 Xml;HDR=YES"";"
$OleDbConn.Open()
$OleDbCmd.Connection = $OleDbConn
$OleDbCmd.CommandText = ("Select * from [{0}$] Where ShutdownOrder={1}" -f $ExcelSheet, $Order)
$OleDbAdapter.SelectCommand = $OleDbCmd
$RowsReturned = $OleDbAdapter.Fill($Table)
$OleDbConn.Close()

foreach ($TableRow in $Table.Rows) {

	$VM = $null
	$VM = Get-View -Id ("{0}" -f $TableRow.vmID) -ErrorAction:SilentlyContinue
	if (!$VM) {
		Write-INGLog -Message ("{0}: VM does not exist" -f $TableRow.Name) -Severity ERROR
		Continue
	}
	
	if ($ShutDownControl) {
		if ($VM.Runtime.PowerState -eq "PoweredOff") {
			#Write-INGLog -Message ("{0}: VM is powered off" -f $TableRow.Name) -Severity INFO
		} else {
			Write-INGLog -Message ("{0}: VM is still running" -f $TableRow.Name) -Severity WARNING
			#$VM.PowerOffVM()
		}
	}
	
	if (!$ShutDownControl) {
		if ($VM.Runtime.PowerState -eq "PoweredOff") {
			Write-INGLog -Message ("{0}: VM is already powered off" -f $TableRow.Name) -Severity WARNING
			Continue
		}
		
		$VMToolState = $VM.Guest.ToolsRunningStatus
		
		if ($VMToolState -eq "guestToolsNotRunning") {
			Write-INGLog -Message ("{0}: VMtools not running, powering off" -f $TableRow.Name) -Severity WARNING
			$VM.PowerOffVM()
			Start-Sleep -Milliseconds 1000
		} else {
			Write-INGLog -Message ("{0}: VMtools running, shutting down" -f $TableRow.Name) -Severity INFO
			$VM.ShutdownGuest()
			Start-Sleep -Milliseconds 1000
		}
	}
}

UninitializeEnvironment

# [END] ....................................................................................