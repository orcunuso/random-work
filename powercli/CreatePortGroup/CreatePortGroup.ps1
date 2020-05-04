# Subject     : Create Port Groups from VLANS file
# Prepared by : Ozan Orçunus
# Script Name : CreatePortGroup.ps1
# Version     : 1.00

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)][string]$vCenter)

function InitializeEnvironment {
	Import-Module -Name ModING -WarningAction:SilentlyContinue
	Add-PSSnapin VMware.VimAutomation.VdsComponent
	Initialize-INGScript -ScriptName "CreatePortGroup"
}

function UninitializeEnvironment {
	Disconnect-INGvCenter -vCenter $Global:DefaultVIServer.Name
	Uninitialize-INGScript
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

InitializeEnvironment

$ExcelSheet   = "VLANS"
$OleDbConn    = New-Object "System.Data.OleDb.OleDbConnection"
$OleDbCmd     = New-Object "System.Data.OleDb.OleDbCommand"
$OleDbAdapter = New-Object "System.Data.OleDb.OleDbDataAdapter"
$Table        = New-Object "System.Data.DataTable"

$OleDbConn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$Global:XlsFile;Extended Properties=""Excel 12.0 Xml;HDR=YES"";"
$OleDbConn.Open()
$OleDbCmd.Connection = $OleDbConn
$OleDbCmd.CommandText = ("Select * from [{0}$] Where Add='YES'" -f $ExcelSheet)
$OleDbAdapter.SelectCommand = $OleDbCmd
$RowsReturned = $OleDbAdapter.Fill($Table)
$OleDbConn.Close()

foreach ($TableRow in $Table.Rows) {

	switch ($TableRow.vCenter) {
		"DC1VC"	{ $CurrentvCenter = "dc1vc01.mydomain.local" }
		"DC2VC"	{ $CurrentvCenter = "dc2vc01.mydomain.local" }
		"DC3VC"	{ $CurrentvCenter = "dc3vc01.mydomain.local" }
		"PREVC"	{ $CurrentvCenter = "dc1vc03.mydomain.local" }
	}

	$PG_Name      = ("dvp.{0}.{1}.{2}" -f $TableRow.BuildingBlock,$TableRow.Tier,$TableRow.Vlan)
	$PG_Ports     = $TableRow.Count / 4
	
	New-VdsDistributedPortGroup -Name $PG_Name -Vds $TableRow.Parent -ReferenceDVPortgroup "dvp.Rsf.Middle.400" -VLanId $TableRow.Vlan -Notes $TableRow.VlanName -NumPorts $PG_Ports
}

UninitializeEnvironment