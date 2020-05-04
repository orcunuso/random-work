# Project     : Automated VM Poweron
# Prepared by : Ozan Orçunus
#

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)] [string]$vCenter,
		[Parameter(Mandatory=$false)][string]$Cluster,
		[Parameter(Mandatory=$true)] [int]$Order,
		[Switch]$PoweronControl )

function InitializeEnvironment {
	Import-Module -Name ModING -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "DC2Poweron"
	Connect-INGvCenter -vCenter $vCenter
}

function UninitializeEnvironment {
	Disconnect-INGvCenter -vCenter $vCenter
	Uninitialize-INGScript
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
if ($Cluster) { $OleDbCmd.CommandText = ("Select * from [{0}$] Where ShutdownOrder={1} And Cluster='{2}'" -f $ExcelSheet, $Order, $Cluster) }
	else { $OleDbCmd.CommandText = ("Select * from [{0}$] Where ShutdownOrder={1}" -f $ExcelSheet, $Order) }
$OleDbAdapter.SelectCommand = $OleDbCmd
$RowsReturned = $OleDbAdapter.Fill($Table)
$OleDbConn.Close()

foreach ($TableRow in $Table.Rows) {
	
	$VM = $null
	$VM = Get-View -Id ("{0}" -f $TableRow.vmID) -ErrorAction:SilentlyContinue
	if (!$VM) {
		Write-INGLog -Message ("{0}: VM does not exist" -f $TableRow.Name) -Color "RED"
		Continue
	}
	
	if ($PoweronControl) {
		if ($VM.Runtime.PowerState -eq "poweredOff") {
			Write-INGLog -Message ("{0}: VM is still powered off" -f $TableRow.Name) -Color "YELLOW"
			Continue
		}
		
		$VMToolState = $VM.Guest.ToolsRunningStatus
		if ($VMToolState -eq "guestToolsNotRunning") {
			Write-INGLog -Message ("{0}: VMtools not running" -f $TableRow.Name) -Color "YELLOW"
		} else {
			Write-INGLog -Message ("{0}: VMtools running, server up and running" -f $TableRow.Name) -Color "CYAN"
		}
	}
	
	if (!$PoweronControl) {
		if ($VM.Runtime.PowerState -eq "poweredOn") {
			Write-INGLog -Message ("{0}: VM is already powered on" -f $TableRow.Name) -Color "YELLOW"
			Continue
		}
		
		Write-INGLog -Message ("{0}: VM is starting" -f $TableRow.Name) -Color "CYAN"
		$VM.PowerOnVM($null)
	}
}

UninitializeEnvironment

# [END] ....................................................................................