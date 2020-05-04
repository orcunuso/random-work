# Subject     : Change Backup Annotation from VMs
# Prepared by : Ozan Orçunus
# Script Name : BackupGroupGecici.ps1
# Version     : 1.00

# [FUNCTIONS - General] =================================================================

$Global:ScriptName = "NetAppLunMap"

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
$ESXHosts = ("","","")

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
	foreach ($ESXHost in $ESXHosts) {
		Write-Host ("lun map {0} {1} {2}" -f $TableRow.LunPath, $ESXHost, $TableRow.LunID)
	}
}

Uninitialize-INGScript