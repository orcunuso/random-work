# Subject     : Change Annotation from All VMs
# Prepared by : Ozan Orçunus
# Script Name : ChangeAnnotation.ps1
# Version     : 1.00
# Note        : Script accepts multiple annotations with format: Annotation1-Annotation2-Annotation3
#	          : Required Columns: vCenter, Name, Change, Related Annotation and ID

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)][string]$AnnotationsToChange)

function InitializeEnvironment {
	Import-Module -Name INGPSModule -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "ChangeAnnotation"
}

function UninitializeEnvironment {
	Disconnect-INGvCenter -vCenter $Global:DefaultVIServer.Name
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
$OleDbCmd.CommandText = ("Select * from [{0}$] Where Change='YES'" -f $ExcelSheet)
$OleDbAdapter.SelectCommand = $OleDbCmd
$RowsReturned = $OleDbAdapter.Fill($Table)
$OleDbConn.Close()

foreach ($TableRow in $Table.Rows) {

	switch ($TableRow.vCenter) {
		"DC1VC"	{ $CurrentvCenter = "dc1vc01.mydomain.local" }
		"DC2VC"	{ $CurrentvCenter = "dc2vc01.mydomain.local" }
		"DC3VC"	{ $CurrentvCenter = "dc3vc01.mydomain.local" }
		"PREVC"	{ $CurrentvCenter = "dc1vc03.mydomain.local" }
		"dc2vcSA02"	{ $CurrentvCenter = "dc2vcsa02.mydomain.local"   }
	}
	
	if ($Global:DefaultVIServer -eq $null) { 
		Connect-INGvCenter -vCenter $TableRow.vCenter
	} else {
		if ($Global:DefaultVIServer.Name -ne $CurrentvCenter) {
			Disconnect-INGvCenter -vCenter $Global:DefaultVIServer.Name
			Connect-INGvCenter -vCenter $TableRow.vCenter
		}
	}

	$VM = $null
	$VM = Get-View -Id ("VirtualMachine-{0}" -f $TableRow.ID) -ErrorAction:SilentlyContinue
	#$VM = Get-View -Id ("{0}" -f $TableRow.ID) -ErrorAction:SilentlyContinue
	if (!$VM) {
		Write-INGLog -Message ("{0}: VM does not exist" -f $TableRow.Name) -Color Red
		Continue
	}
	
	$Annotations = $AnnotationsToChange.Split("-")	
	foreach ($Annotation in $Annotations) {
		$VM_Annotation       = $VM.AvailableField | Where-Object { $_.Name -eq $Annotation } 
		$VM_Annotation_Key   = $VM_Annotation.Key
		$VM_Annotation_Obj   = $VM.CustomValue | Where-Object { $_.Key -eq $VM_Annotation_Key }
		$VM_Annotation_Value = $VM_Annotation_Obj.Value
		
		if ($VM_Annotation_Value -eq $TableRow.$Annotation) {
			Write-INGLog -Message ("{0} - {1} is the same as the one from the input file: {2}" -f $VM.Name, $Annotation, $TableRow.$Annotation)
		} else {
			$VM.setCustomValue($Annotation,$TableRow.$Annotation)
			Write-INGLog -Message ("{0} - {1} has been changed to: {2}" -f $VM.Name, $Annotation, $TableRow.$Annotation) -Color Cyan
		}
	}
}

UninitializeEnvironment