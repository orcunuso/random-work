# Prepared by : Ozan Orçunus
#

# [FUNCTIONS - General] =================================================================
		
$Global:ScriptName = "VMware-Check-SAN"

function Initialize-INGScript {	
	If (Test-Path -Path "D:\Users\oorcunus\Documents\Scripts") { 
		$Global:ScrPath   = ("D:\Users\oorcunus\Documents\Scripts\{0}\" -f $Global:ScriptName)
	} else {
		$Global:ScrPath   = ("C:\Scripts\{0}\" -f $Global:ScriptName)
	}
	
	$Global:LogFile   = ("{0}{1}.log"      -f $Global:ScrPath,$Global:ScriptName)
	$Global:XlsFile   = ("{0}{1}.xlsx"     -f $Global:ScrPath,$Global:ScriptName)
	$Global:CtrlFile  = ("{0}{1}.ctrl"     -f $Global:ScrPath,$Global:ScriptName)
	$Global:OutFile   = ("{0}{1}_Out.xlsx" -f $Global:ScrPath,$Global:ScriptName)
	$Global:InFile    = ("{0}{1}.input"    -f $Global:ScrPath,$Global:ScriptName)
	
	Confirm-INGPowerCLI $Global:ScrPath
	Write-INGLog (" ")
	Write-INGLog ("***************** Script started *******************")
}

function Confirm-INGPowerCLI {
	param ([String]$PSPath)
	$VMSnapin = (Get-PSSnapin | Where {$_.Name -eq "VMware.VimAutomation.Core"}).Name
	if ($VMSnapin -ne "VMware.VimAutomation.Core") {
		CD "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\"
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
	$Global:InFile    = $null
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
		"dc1vm"  { $vCenterFQDN = "dc1vm.mydomain.local"   }
	}
	try {
		if ($Credential) {
			#Connect-VIServer -Server $vCenterFQDN -Credential $Credential -WarningAction:SilentlyContinue | Out-Null
		} else {
			Connect-VIServer -Server $vCenterFQDN -User MYDOMAIN\Svcvcorch -Password OPIiQg9n -WarningAction:SilentlyContinue | Out-Null
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
		"dc1vm"  { $vCenterFQDN = "dc1vm.mydomain.local"   }
	}
	
	Disconnect-VIServer -Confirm:$false -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue | Out-Null
	if ($vCenterFQDN) { Write-INGLog -Message ("Disconnected from " + $vCenterFQDN) }
		else { Write-INGLog -Message ("Disconnected from vCenter Server") }
	$host.ui.RawUI.WindowTitle = ("!!!!! NOT CONNECTED TO ANY VCENTER SERVERS !!!!!")
}

function ReadInputFile {
	if (Test-Path -Path $Global:InFile) {
		$File = Get-Content -Path $Global:InFile
		foreach ($Line in $File) {
			if ($Line.StartsWith("#")) { continue }
			$InputParameter = ($Line.Split("=")[0]).Trim()
			$InputValue     = ($Line.Split("=")[1]).Trim()
			switch ($InputParameter) {
				"CLUSTER"	{ $Global:Clusters += $InputValue }
				default		{ continue }
			}
		}
		return $true
	} else {
		return $false
	}
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

Initialize-INGScript
$Global:Clusters = @()

if (ReadInputFile) {
	foreach ($ClusterInput in $Global:Clusters) {
		$vCenter = $ClusterInput.Split(":")[0]
		$Cluster = $ClusterInput.Split(":")[1]

		Connect-INGvCenter -vCenter $vCenter
		$VMHosts      = Get-Cluster -Name $Cluster | Get-VMHost | Where-Object { $_.ConnectionState -eq "Connected" }
		$ProblemDisks = @()
		$ProblemCount = 0
		$TotalPathCount = 0
	
		Write-INGLog -Message ("===== ANALIZ EDILEN CLUSTER: {0} =====" -f $Cluster) -Color Green
		foreach ($VMHost in $VMHosts) {
			Write-INGLog -Message ("Analiz edilen sunucu: {0}" -f $VMHost.Name) -Color Cyan
			$ScsiLUNs     = Get-ScsiLun -VMHost $VMHost -LunType disk
			$ScsiLUNPaths = Get-ScsiLunPath -ScsiLun $ScsiLUNs
			$TotalHostPathCount = 0
			foreach ($ScsiLUNPath in $ScsiLUNPaths) {
				if ($ScsiLUNPath.State.ToString() -eq "Active" -or $ScsiLUNPath.State.ToString() -eq "Standby") {
					$TotalPathCount++
				} else {
					$ProblemDisks += ("{0}->{1}" -f $VMHost.Name,$ScsiLUNPath)
					$ProblemCount++ 
				}
				$TotalHostPathCount++
			}
			Write-INGLog -Message ("Toplam path sayisi (lokal disk dahil): {0}" -f $TotalHostPathCount)
		}

		Write-INGLog -Message (" ")
		Write-INGLog -Message ("{0} adet path aktif gorunuyor" -f $TotalPathCount)
		if ($ProblemCount -eq 0) {
			Write-INGLog -Message ("Dead gorunen hic bir path yok")
		} else {
			Write-INGLog -Message ("Toplam {0} path'de problem var:" -f $ProblemCount)
			Write-INGLog -Message "================================="
			foreach ($Log in $ProblemDisks) {
				Write-INGLog -Message $Log -Color Yellow -NoDateLog
			}
		}
		Disconnect-INGvCenter -vCenter $vCenter
	}
} else {
	Write-INGLog -Message ("Input file cannot be found: {0}" -f $Global:InFile) -Color Red
}

Uninitialize-INGScript

# [END] ....................................................................................