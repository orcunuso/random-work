# Version     : 1.00
# Create Date : 25.08.2012
# Modify Date : 25.08.2012 20:11

# [FUNCTIONS - General] ....................................................................

Function CheckPowerCLI {
	Param ([String]$PSPath)
	
	$VMSnapin = (Get-PSSnapin | Where {$_.Name -eq "VMware.VimAutomation.Core"}).Name
	If ($VMSnapin -ne "VMware.VimAutomation.Core") {
		CD "C:\Program Files\VMware\Infrastructure\vSphere PowerCLI\Scripts\"
		Add-PSSnapin VMware.VimAutomation.Core
		.\Initialize-PowerCLIEnvironment.ps1
		CD $PSPath
	}
}

Function WriteLog {
	Param ([String]$File, [String]$Message)
	
	$LogMessage = (Get-Date).ToString() + " | " + $Message
	$LogMessage >> $File
	Write-Host $LogMessage
}

Function AddTemplatesToInventory {
	Param ([String]$Location,[String]$TMPLFile)
	
	$TMPLCount = 0
	Switch ($Location) {
		"DC1" {Connect-VIServer "DC1VC"}
	}
	$ESXs = Get-Cluster "RSFBB" | Get-VMHost | Where {$_.ConnectionState -eq "Connected"} | Sort Name
	Foreach ($Template in (Import-CSV $TMPLFile)) {
		$ESXHost = $ESXs.Get(($TMPLCount %= $ESXs.Count))
		Switch ($Location) {
			"DC1" {$TemplatePath = "[" + $Template.DC1DataStore + "] " + $Template.PathName}
		}
		$TemplateDestination = Get-View -ViewType Folder -Property Name -Filter @{"Name" = $Template.Folder}
		$TemplateDestination.RegisterVM_Task($TemplatePath, $Template.Name, $True, $Null, (Get-View -ViewType HostSystem -Property Name -Filter @{"Name" = $ESXHost.Name}).MoRef) > $Null
		WriteLog $Global:LogFile ("Adding template (" + $Template.Name + ") to inventory via (" + $ESXHost + ")")
		$TMPLCount++
	}
	Disconnect-VIServer -Confirm:$False
}

Function RemoveTemplateFromInventory {
	Param ([String]$Location,[String]$TMPLFile)
	
	$TMPLCount = 0
	Switch ($Location) {
		"DC1" {Connect-VIServer "DC1VC"}
	}
	
	$ESXs = Get-Cluster "" | Get-VMHost | Where {$_.ConnectionState -eq "Connected"} | Sort Name
	Foreach ($Template in (Import-CSV $TMPLFile)) {
		$ESXHost = $ESXs.Get(($TMPLCount %= $ESXs.Count))
		Switch ($Location) {
			"DC1" {$TemplatePath = "[" + $Template.DC1DataStore + "] " + $Template.PathName}
		}
		$TemplateDestination = Get-View -ViewType Folder -Property Name -Filter @{"Name" = $Template.Folder}
	}
	
}

# [MAIN] ...................................................................................

# NOTE : Set Global variables
$Global:ScrPath    = "D:\Library\Scripts\POWERCLI\VM\Prod\"
$Global:LogFile    = $Global:ScrPath + "Sync-Templates.log"
$Global:TMPLFile   = $Global:ScrPath + "Sync-Templates.csv"

# NOTE : Start using functions
CheckPowerCLI $Global:ScrPath
AddTemplatesToInventory "DC1" $Global:TMPLFile

# [END] ....................................................................................
