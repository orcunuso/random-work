# Subject     : Change Backup Annotation from VMs
# Prepared by : Ozan Orçunus
# Script Name : BackupGroupGecici.ps1
# Version     : 1.00

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)][string]$EnableOrDisable,
		[Parameter(Mandatory=$false)][string]$EnablevCenter )

$Global:ScriptName = "BackupGroupGecici"

function Initialize-INGScript {
	[CmdletBinding()]
	param ( [Parameter(Mandatory=$true)][String]$ScriptName)
	
	If (Test-Path -Path "D:\Users\oorcunus\Documents\Scripts") { 
		$Global:ScrPath   = ("D:\Users\oorcunus\Documents\Scripts\{0}\" -f $ScriptName)
	} else {
		$Global:ScrPath   = ("C:\Scripts\")
	}
	
	$Global:LogFile   = ("{0}{1}.log"      -f $Global:ScrPath,$ScriptName)
	$Global:XlsFile   = ("{0}{1}.xlsx"     -f $Global:ScrPath,$ScriptName)
	$Global:CtrlFile  = ("{0}{1}.ctrl"     -f $Global:ScrPath,$ScriptName)
	$Global:OutFile   = ("{0}{1}_Out.xlsx" -f $Global:ScrPath,$ScriptName)
	$Global:ScrptName = $ScriptName
	
	Confirm-INGPowerCLI $Global:ScrPath
	Write-INGLog (" ")
	Write-INGLog ("***************** Script started *******************")
}

function Confirm-INGPowerCLI {
	param ([String]$PSPath)
	$VMSnapin = (Get-PSSnapin | Where {$_.Name -eq "VMware.VimAutomation.Core"}).Name
	if ($VMSnapin -ne "VMware.VimAutomation.Core") {
		CD "C:\Program Files\VMware\Infrastructure\vSphere PowerCLI\Scripts\"
		Add-PSSnapin VMware.VimAutomation.Core
		.\Initialize-PowerCLIEnvironment.ps1
		CD $PSPath
	}
}

function Uninitialize-INGScript {
	if ($Global:DefaultVIServer) { 
		Disconnect-VIServer * -Confirm:$false -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue
		Write-INGLog -Message ("Disconnected from all vCenter Servers")
		$host.ui.RawUI.WindowTitle = ("!!!!! NOT CONNECTED TO ANY VCENTER SERVERS !!!!!")
	}
	Write-INGLog ("***************** Script completed *****************")
	$Global:ScrPath   = $null
	$Global:LogFile   = $null
	$Global:XlsFile   = $null
	$Global:CtrlFile  = $null
	$Global:OutFile   = $null
}

function Write-INGLog {
	[CmdletBinding()]
	param ( [Parameter(Mandatory=$true)][String]$Message, 
			[string]$Color,
			[switch]$NoReturn,
			[switch]$NoDateLog)
	
	if (!$Color) { $Color = "WHITE" }
	if ($NoDateLog) { $LogMessage = $Message }
		else { $LogMessage = (Get-Date).ToString() + " | " + $Message }
	
	Write-Host $LogMessage -ForegroundColor $Color -NoNewline:$NoReturn
	Out-File -InputObject $LogMessage -FilePath $Global:LogFile -Append -NoClobber -Confirm:$false -ErrorAction:SilentlyContinue
}

function Connect-INGvCenter {
	param ( [Parameter(Mandatory=$true)][String]$vCenter, 
			[System.Management.Automation.PSCredential]$Credential)
			
	$vCenterFQDN = $vCenter
	switch ($vCenter) {
		"dc1vm" { $vCenterFQDN = "dc1vm.mydomain.local"   }
		"dc2vm" { $vCenterFQDN = "dc2vm.mydomain.local"   }
		"DC1VC"  { $vCenterFQDN = "dc1vc01.mydomain.local" }
		"PREVC"  { $vCenterFQDN = "dc1vc03.mydomain.local" }
		"DC2VC"  { $vCenterFQDN = "dc2vc01.mydomain.local" }
	}
	try {
		if ($Credential) {
			Connect-VIServer -Server $vCenterFQDN -Credential $Credential -WarningAction:SilentlyContinue | Out-Null
		} else {
			Connect-VIServer -Server $vCenterFQDN -WarningAction:SilentlyContinue | Out-Null
		}
		Write-INGLog ("Connected to " + $vCenterFQDN)
		$host.ui.RawUI.WindowTitle = ("CONNECTED TO " + $vCenter)
	} catch {
		Write-INGLog ("Cannot connect to " + $vCenterFQDN) -Color RED
	}
}

function Disconnect-INGvCenter {
	[CmdletBinding()]
	param ([String]$vCenter)
	
	$vCenterFQDN = $vCenter
	switch ($vCenter) {
		"dc1vm" { $vCenterFQDN = "dc1vm.mydomain.local"   }
		"dc2vm" { $vCenterFQDN = "dc2vm.mydomain.local"   }
		"DC1VC"  { $vCenterFQDN = "dc1vc01.mydomain.local" }
		"PREVC"  { $vCenterFQDN = "dc1vc03.mydomain.local" }
		"DC2VC"  { $vCenterFQDN = "dc2vc01.mydomain.local" }
	}
	
	Disconnect-VIServer -Confirm:$false -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue | Out-Null
	if ($vCenterFQDN) { Write-INGLog -Message ("Disconnected from " + $vCenterFQDN) }
		else { Write-INGLog -Message ("Disconnected from vCenter Server") }
	$host.ui.RawUI.WindowTitle = ("!!!!! NOT CONNECTED TO ANY VCENTER SERVERS !!!!!")
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

Initialize-INGScript -ScriptName $Global:ScriptName

if ($EnableOrDisable -eq "Enable") { 
	if ($EnablevCenter) {
		Connect-INGvCenter -vCenter $EnablevCenter
		$VMs = Get-VM
		foreach ($VM in $VMs) {
			$VM_OldBackupGroup = ($VM.ExtensionData.CustomValue | Where {$_.Key -eq ($VM.ExtensionData.AvailableField | Where {$_.Name -eq "BackupGroup"}).Key}).Value
			if ($VM_OldBackupGroup -match "Gecici") {
				$Array = $VM_OldBackupGroup.Split("_")
				$VM_NewBackupGroup = ("{0}_{1}_{2}" -f $Array[0], $Array[1], $Array[3])
				Write-INGLog -Message ("{0}: BackupGroup contains Gecici, changing to {1}" -f $VM.Name, $VM_NewBackupGroup)
				Set-Annotation -Entity $VM -CustomAttribute "BackupGroup" -Value $VM_NewBackupGroup -Confirm:$false | Out-Null
			}
		}
	} else {
		Write-INGLog -Message ("No vCenter Server specified!!!") -Color Yellow
	}
}

if ($EnableOrDisable -eq "Disable") {

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
			"dc1vm"	{ $CurrentvCenter = "dc1vm.mydomain.local"   }
			"DC2VC"	{ $CurrentvCenter = "dc2vc01.mydomain.local" }
			"PREVC"	{ $CurrentvCenter = "dc1vc03.mydomain.local" }
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
		$VM = Get-VM -Name $TableRow.Name -ErrorAction:SilentlyContinue
		if (!$VM) {
			Write-INGLog -Message ("{0}: VM does not exist" -f $TableRow.Name) -Color Red
			Continue
		}
		
		if ($EnableOrDisable -eq "Disable") {  
			$VM_BackupGroup = ($VM.ExtensionData.CustomValue | Where {$_.Key -eq ($VM.ExtensionData.AvailableField | Where {$_.Name -eq "BackupGroup"}).Key}).Value
			
			if (!$VM_BackupGroup) {
				Write-INGLog -Message ("{0}: BackupGroup is null" -f $VM.Name)
				Continue
			}
			if ($VM_BackupGroup -eq "NoBackup") {
				Write-INGLog -Message ("{0}: BackupGroup is NoBackup" -f $VM.Name)
				Continue
			}
			if ($VM_BackupGroup -match "Gecici") {
				Write-INGLog -Message ("{0}: BackupGroup is already Gecici" -f $VM.Name)
				Continue
			}
			
			$Array = $VM_BackupGroup.Split("_")
			$VM_NewBackupGroup = ("{0}_{1}_Gecici_{2}" -f $Array[0], $Array[1], $Array[2])
			Set-Annotation -Entity $VM -CustomAttribute "BackupGroup" -Value $VM_NewBackupGroup -Confirm:$false | Out-Null
			Write-INGLog -Message ("{0} - {1} has been changed to: {2}" -f $VM.Name, "BackupGroup", $VM_NewBackupGroup) -Color Cyan
		}
	}
}
Uninitialize-INGScript

#$VMs = Get-Cluster -Name TESTNDEV.ORABB | Get-VM
#foreach ($VM in $VMs) { Set-Annotation -Entity $VM -CustomAttribute "BackupGroup" -Value "NoBackup" -Confirm:$false | Out-Null; Write-Host ("{0} ok" -f $VM.Name) }