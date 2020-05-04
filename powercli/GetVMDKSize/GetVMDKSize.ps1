# Project     : Get VMDK Size Info
# Prepared by : Ozan Orçunus
# Create Date : 04.11.2013
# Modify Date : 04.11.2013
#

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)][string]$vCenter)

function InitializeEnvironment {
	Import-Module -Name ModING -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "GetVMDKSize"
	Connect-INGvCenter -vCenter $vCenter
}

function UninitializeEnvironment {
	Uninitialize-INGScript
	Disconnect-INGvCenter -vCenter $vCenter
}

function UpdateTableRow {
	param ([String]$UpdateField, [String]$UpdateValue, [String]$DiskName)
	$ExcelSheet   = "GetVMDKSize"
	$OleDbConn    = New-Object "System.Data.OleDb.OleDbConnection"
	$OleDbCmd     = New-Object "System.Data.OleDb.OleDbCommand"
	$OleDbConn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$Global:XlsFile;Extended Properties=""Excel 12.0 Xml;HDR=YES"";"
	$OleDbConn.Open()
	$OleDbCmd.Connection = $OleDbConn
	$OleDbCmd.CommandText = ("Update [{0}$] Set {1}='{2}' Where Name='{3}'" -f $ExcelSheet,$UpdateField,$UpdateValue,$DiskName)
	$OleDbCmd.ExecuteNonQuery() | Out-Null
	$OleDbConn.Close()
}

function ParseDatastore {
	param ([String]$DiskFullPath)
	$Datastore = Get-Datastore -Name $DiskFullPath.Split(("[","]"))[1]
	return $Datastore
}

function ParseFileName {
	param ([String]$DiskFullPath)
	return [String]$DiskFullPath.Split("/")[1]
}

function ParseRootPath {
	param ([String]$DiskFullPath)
	return $DiskFullPath.Split("/")[0] + "/"
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

InitializeEnvironment

$ExcelSheet   = "GetVMDKSize"
$OleDbConn    = New-Object "System.Data.OleDb.OleDbConnection"
$OleDbCmd     = New-Object "System.Data.OleDb.OleDbCommand"
$OleDbAdapter = New-Object "System.Data.OleDb.OleDbDataAdapter"
$Table        = New-Object "System.Data.DataTable"

$OleDbConn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$Global:XlsFile;Extended Properties=""Excel 12.0 Xml;HDR=YES"";"
$OleDbConn.Open()
$OleDbCmd.Connection = $OleDbConn
$OleDbCmd.CommandText = ("Select * from [{0}$] Where Message='Possibly a Zombie vmdk file! Please check.'" -f $ExcelSheet)
$OleDbAdapter.SelectCommand = $OleDbCmd
$RowsReturned = $OleDbAdapter.Fill($Table)
$OleDbConn.Close()

foreach ($TableRow in $Table.Rows) {
	$DS = ParseDatastore -DiskFullPath $TableRow.Name | % {Get-View $_.Id}
	$FileQueryFlags = New-Object VMware.Vim.FileQueryFlags
	$FileQueryFlags.FileSize = $true
	$FileQueryFlags.FileType = $true
	$FileQueryFlags.Modification = $true
	$SearchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
	$SearchSpec.Details = $fileQueryFlags
	$SearchSpec.MatchPattern = ParseFileName -DiskFullPath $TableRow.Name
	$SearchSpec.SortFoldersFirst = $true
	$dsBrowser = Get-View $DS.browser
	$rootPath = ParseRootPath -DiskFullPath $TableRow.Name
	$SearchResult = $dsBrowser.SearchDatastoreSubFolders($rootPath, $SearchSpec)
	
	Write-INGLog -Message ("{0} -> Size: {1}" -f $TableRow.Name, $SearchResult[0].File[0].FileSize)
	#UpdateTableRow -UpdateField "Size" -UpdateValue $SearchResult[0].File[0].FileSize -DiskName $TableRow.Name 
	
	$FileQueryFlags = $null
	$SearchSpec = $null
}

Write-INGLog -Message $Table.Rows.Count

UninitializeEnvironment
Exit

# [END] ....................................................................................



$ds = Get-Datastore -Name LOC.Dmzbb.01.2A | % {Get-View $_.Id}
$fileQueryFlags = New-Object VMware.Vim.FileQueryFlags
$fileQueryFlags.FileSize = $true
$fileQueryFlags.FileType = $true
$fileQueryFlags.Modification = $true
$searchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
$searchSpec.details = $fileQueryFlags
$searchSpec.matchPattern = "DC1VM-000009.vmdk"
$searchSpec.sortFoldersFirst = $true
$dsBrowser = Get-View $ds.browser
$rootPath = "[" + $ds.Name + "]" + " DC1VM/"
$searchResult = $dsBrowser.SearchDatastoreSubFolders($rootPath, $searchSpec)











