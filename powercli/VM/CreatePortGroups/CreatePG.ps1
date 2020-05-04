# Project     : Avrasya Create Portgroups - NotReady
# Prepared by : Ozan Orçunus
# Create Date : 06.02.2013
# Modify Date : 06.02.2013

# [FUNCTIONS - General] =================================================================

function CheckPowerCLI 
{
	param ([String]$PSPath)
	$VMSnapin = (Get-PSSnapin | Where {$_.Name -eq "VMware.VimAutomation.Core"}).Name
	if ($VMSnapin -ne "VMware.VimAutomation.Core") {
		CD "C:\Program Files\VMware\Infrastructure\vSphere PowerCLI\Scripts\"
		Add-PSSnapin VMware.VimAutomation.Core
		.\Initialize-PowerCLIEnvironment.ps1
		CD $PSPath
	}
}

function WriteLog
{
	param ([String]$Message)
	$LogMessage = (Get-Date).ToString() + " | " + $Message
	$LogMessage >> $Global:LogFile
	Write-Host $LogMessage
}

function QuitScript
{
	param ([String]$Message, [String]$StatusUpdate)
	WriteLog $Message
	UpdateTableRow $StatusUpdate
	Disconnect-VIServer -Confirm:$False
	WriteLog ("*********** Script ended ***********")
	Exit(0)
}

function UpdateTableRow
{
	param ([String]$Status)
	$ExcelSheet   = "DeployVM"
	$OleDbConn    = New-Object "System.Data.OleDb.OleDbConnection"
	$OleDbCmd     = New-Object "System.Data.OleDb.OleDbCommand"
	$OleDbConn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$Global:XlsFile;Extended Properties=""Excel 12.0 Xml;HDR=YES"";"
	$OleDbConn.Open()
	$OleDbCmd.Connection = $OleDbConn
	$OleDbCmd.CommandText = ("Update [{0}$] Set Status='{1}' Where Name='{2}'" -f $ExcelSheet,$Status,$Global:VMName)
	$OleDbCmd.ExecuteNonQuery()
	$OleDbConn.Close()
}

function ConnectVCenter 
{
	param ([String]$vCenter)
	Connect-VIServer -Server $vCenter -User $Global:Creds[0].User -Password $Global:Creds[0].Password > $Null
	WriteLog ("Connected to " + $vCenter)
}

# [MAIN] =====================================================================================

CheckPowerCLI
Add-PSSnapin VMware.VimAutomation.VdsComponent

$Global:ScrPath   = "D:\Library\Scripts\Powershell\VM\CreatePortGroups\"
$Global:LogFile   = $Global:ScrPath + "CreatePG.log"
$Global:XlsFile   = $Global:ScrPath + "CreatePG.xlsx"
$Global:CtrlFile  = $Global:ScrPath + "CreatePG.cnt"
$Global:Creds     = Get-VICredentialStoreItem -File D:\Library\Tools\Credentials\vSphereCredentials.xml
$index            = 0

$ExcelSheet   = "CreatePG"
$OleDbConn    = New-Object "System.Data.OleDb.OleDbConnection"
$OleDbCmd     = New-Object "System.Data.OleDb.OleDbCommand"
$OleDbAdapter = New-Object "System.Data.OleDb.OleDbDataAdapter"
$Table        = New-Object "System.Data.DataTable"

$OleDbConn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$Global:XlsFile;Extended Properties=""Excel 12.0 Xml;HDR=YES"";"
$OleDbConn.Open()
$OleDbCmd.Connection = $OleDbConn
$OleDbCmd.CommandText = "Select * from [$ExcelSheet$]"
$OleDbAdapter.SelectCommand = $OleDbCmd
$RowsReturned = $OleDbAdapter.Fill($Table)
$OleDbConn.Close()

WriteLog ("********** Script started **********")

while ($index -lt $RowsReturned)
{
	$TableRow = $Table.Rows[$index]
	if ($TableRow.Status -ne "Requested") { $index++; continue }
	
	$VDS = Get-VDS -Name $TableRow.DVSName
	New-VdsDistributedPortgroup -Name $TableRow.PortGroupName -Vds $VDS -VlanType "VLAN" -VlanId $TableRow.VLANID -Notes $TableRow.Description -NumPorts $TableRow.PortCount -Confirm:$false
	$VPG = Get-VdsDistributedPortgroup -Name $TableRow.PortGroupName
	Set-VdsDistributedPortgroup -DVPortgroup $VPG 
	

}



