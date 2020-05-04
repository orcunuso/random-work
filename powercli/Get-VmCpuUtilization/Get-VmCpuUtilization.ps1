# Project     : Realtime CPu Utilizations 
# Prepared by : Ozan Orçunus
#

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)] [string]$vCenter,
		[Parameter(Mandatory=$true)] [string]$Cluster )

function InitializeEnvironment {
	Import-Module -Name INGPSModule -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "Get-VmCpuUtilization"
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

$StopH = 18
$StopM = 0
$TimeToStop = Get-Date -Year (Get-Date).Year -Month (Get-Date).Month -Day (Get-Date).Day -Hour $StopH -Minute $StopM -Second 0
Write-INGLog -Message ("Script will stop at {0}:{1}" -f $StopH, $StopM)

do {
	Write-INGLog -Message ("Iteration running...") -NoReturn
	$TimerDone  = ((Get-Date) -gt $TimeToStop)

	$File      = "Get-VmCpuUtilization.csv"
	$VMs       = Get-Cluster -Name $Cluster | Get-VM
	$String1   = ("{0}," -f (Get-Date))
	$VMobjs    = New-Object System.Collections.ArrayList
	
	foreach ($VM in $VMs) {
		$VMobj = "" | Select-Object Name,Utilization
		$VMobj.Name = $VM.Name
		$VMobj.Utilization = $VM.ExtensionData.Summary.QuickStats.OverallCpuDemand
		$VMobjs.Add($VMobj) | Out-Null
	}
	$VMobjs = $VMobjs | Sort-Object Utilization -Descending
	
	foreach ($Item in $VMobjs) {
		$String1 += ("{0}-{1}," -f $Item.Utilization, $Item.Name)
	}
	
	Add-Content -Path $File -Value $String1 -Confirm:$false | Out-Null
	Write-INGLog -Message ("Terminated") -NoDateLog
	Start-Sleep -Seconds 900
} while (!$TimerDone)

Write-INGLog -Message ("Script terninated!!!")

UninitializeEnvironment

# [END] ....................................................................................














