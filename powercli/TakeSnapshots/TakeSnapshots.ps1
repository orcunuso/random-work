# Project     : Operational
# Script Name : TakeSnapshots.ps1
# Version     : 1.05
# Create Date : 30.01.2013
# Modify Date : 02.04.2013

# [FUNCTIONS - General] =================================================================

function InitializeEnvironment {
	Import-Module -Name ModING -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "TakeSnapshots"
}

function UninitializeEnvironment {
	Disconnect-INGvCenter -vCenter $Global:DefaultVIServer
	Uninitialize-INGScript
}

function UpdateTableRow {
	param ([String]$Status, [String]$Field, [String]$VirtualMachineName)
	$ExcelSheet   = "TakeSnapshots"
	$OleDbConn    = New-Object "System.Data.OleDb.OleDbConnection"
	$OleDbCmd     = New-Object "System.Data.OleDb.OleDbCommand"
	$OleDbConn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$Global:XlsFile;Extended Properties=""Excel 12.0 Xml;HDR=YES"";"
	$OleDbConn.Open()
	$OleDbCmd.Connection = $OleDbConn
	$OleDbCmd.CommandText = ("Update [{0}$] Set {1}='{2}' Where VM='{3}'" -f $ExcelSheet,$Field,$Status,$VirtualMachineName)
	try {
		$OleDbCmd.ExecuteNonQuery() | Out-Null
	} catch {
		Write-INGLog ("Error occured while updating Excel") "ERROR"
		$ErrorMessage = $_.Exception.Message
		Write-INGLog ("{0}" -f $ErrorMessage)
	} finally {
		$OleDbConn.Close()
	}
}

function SendMail {
	$MailTo     = @("")
	$MailFrom   = ""
	$Subject    = "VM Snapshot Report"
	$Body       = "Please refer to attached file for detailed information"
	$Attachment = $Global:XlsFile
	Send-MailMessage -To $MailTo -From $MailFrom -Subject $Subject -Body $Body -Attachments $Attachment -SmtpServer "INTSMTP"
}

function SendMailStart {
	$MailTo     = @("")
	$MailFrom   = ""
	$Subject    = "VM Snapshot Script started"
	$Body       = "VM Snapshot Script started"
	Send-MailMessage -To $MailTo -From $MailFrom -Subject $Subject -Body $Body -SmtpServer "INTSMTP"
}

# [MAIN] ...................................................................................

InitializeEnvironment
$StartHour = 15
$StartMinute = 52

do {
	$DateKontrol = Get-Date
	if (($DateKontrol.Hour -eq $StartHour) -and ($DateKontrol.Minute -eq $StartMinute)) { break }
	Write-INGLog ("Waiting for start time: {0}:{1}" -f $StartHour,$StartMinute)
	Start-Sleep -Seconds 60
} while ($true)

SendMailStart
$ExcelSheet   = "TakeSnapshots"
$OleDbConn    = New-Object "System.Data.OleDb.OleDbConnection"
$OleDbCmd     = New-Object "System.Data.OleDb.OleDbCommand"
$OleDbAdapter = New-Object "System.Data.OleDb.OleDbDataAdapter"
$Table        = New-Object "System.Data.DataTable"

$OleDbConn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$Global:XlsFile;Extended Properties=""Excel 12.0 Xml;HDR=YES"";"
$OleDbConn.Open()
$OleDbCmd.Connection = $OleDbConn
$OleDbCmd.CommandText = ("Select * from [{0}$] Where Status='Requested'" -f $ExcelSheet)
$OleDbAdapter.SelectCommand = $OleDbCmd
$RowsReturned = $OleDbAdapter.Fill($Table)
$OleDbConn.Close()

foreach ($TableRow in $Table) {	
	$Task = $null
	$Date = Get-Date -Uformat "%Y%m%d%H%M"
	$SnapshotName = ("OrchSnap_{0}_{1}" -f $TableRow.SnapName,$Date)
	$SnapshotDescription = ("Retention:{0}" -f $TableRow.Retention)
	
	if ($Global:DefaultVIServer -eq $null) { 
		Connect-INGvCenter -vCenter $TableRow.vCenter 
	} else {
		if ($Global:DefaultVIServer.Name -ne $TableRow.vCenter) {
			Disconnect-INGvCenter -vCenter $Global:DefaultVIServer.Name
			Connect-INGvCenter -vCenter $TableRow.vCenter
		}
	}
	
	$boolMemory  = $false
	$boolQuiesce = $false
	if ($TableRow.Memory -eq "YES")  { $boolMemory  = $true }
	if ($TableRow.Quiesce -eq "YES") { $boolQuiesce = $true }
	
	$VM = $null
	$VM = Get-VM -Name $TableRow.VM -ErrorAction:SilentlyContinue
	
	if ($VM) {
		try {
			$Task = New-Snapshot -VM $TableRow.VM -Name $SnapshotName -Description $SnapshotDescription -Quiesce:$boolQuiesce -Memory:$boolMemory -RunAsync -Confirm:$false
			Start-Sleep -Seconds 6
			if ($Task.State -eq "Error") {
				Write-INGLog ("Snapshot command failed for {0}" -f $TableRow.VM) "ERROR"
				UpdateTableRow "TASK_FAILED" "Status" $TableRow.VM
				$ErrorMessage = $Task.TerminatingError.Message.Replace('"',"")
				$ErrorMessage = $ErrorMessage.Replace("'","")
				UpdateTableRow $ErrorMessage "ErrorMessage" $TableRow.VM
			} else {
				Write-INGLog ("Snapshot command send for {0}" -f $TableRow.VM) "INFO"
				UpdateTableRow "TASK_RUNNING" "Status" $TableRow.VM
				Wait-Task -Task $Task | Out-Null
				$TaskControl = Get-Task | Where-Object { $_.Id -eq $Task.Id }
				if ($TaskControl.State -eq "Success") {
					UpdateTableRow "SNAP_SUCCESS" "Status" $TableRow.VM
					Write-INGLog ("Snapshot successful for {0}" -f $TableRow.VM)
				}
			}
		} catch {
			Write-INGLog ("Snapshot command failed for {0}" -f $TableRow.VM) "ERROR"
			UpdateTableRow "SNAP_FAILED" "Status" $TableRow.VM
			$TaskControl = Get-Task | Where-Object { $_.Id -eq $Task.Id }
			if ($TaskControl.State -eq "Error") {
				UpdateTableRow "SNAP_FAILED" "Status" $TableRow.VM
				Write-INGLog ("Error: {0}" -f $TaskControl.ExtensionData.Info.Error)
				UpdateTableRow $TaskControl.ExtensionData.Info.Error
			}
		}
	} else {
		Write-INGLog ("VM not found: {0}" -f $TableRow.VM) "ERROR"
		UpdateTableRow "TASK_FAILED" "Status" $TableRow.VM
		UpdateTableRow "VM not found" "ErrorMessage" $TableRow.VM
	}
}

SendMail
UninitializeEnvironment