# Prepared by : Ozan Or�unus
# Script Name : TestConnection.ps1
# Version     : 1.00

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)][string]$vCenter,
		[Parameter(Mandatory=$false)][string]$Cluster,
		[Parameter(Mandatory=$false)][string]$VMHost)

function InitializeEnvironment {
	Import-Module -Name ModING -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "TestConnection"
	Connect-INGvCenter -vCenter $vCenter
}

function UninitializeEnvironment {
	Uninitialize-INGScript
}

function ArrayToString {
	param ( [Parameter(Mandatory=$true)][System.Collections.ArrayList]$Array )
	
	$ReturnString = $null
	foreach ($Item in $Array) { $ReturnString += " " + $Item }
	return $ReturnString.TrimStart()
}

# [MAIN] ...................................................................................

InitializeEnvironment

if ($Cluster) { $VMs = Get-Cluster -Name $Cluster | Get-VM | Where-Object { $_.PowerState -eq "PoweredOn" } }
if ($VMHost)  { $VMs = Get-VMHost -Name $VMHost | Get-VM | Where-Object { $_.PowerState -eq "PoweredOn" } }
	
foreach ($VM in $VMs) {
	$HostEntry   = $null
	$IPAddresses = New-Object System.Collections.ArrayList
	$isIPUP      = $false
	$isServerUP  = $false
	$isIPFound   = $false

	$Networks = $VM.ExtensionData.Guest.Net
	foreach ($Network in $Networks) {
		if ($Network.IpAddress) {
			if ($Network.IpAddress[0].Split(".")[0] -eq "10") { 
				$IPAddresses.Add($Network.IpAddress[0]) | Out-Null
				$isIPFound = $true
			}
		}
	}

	try { $HostEntry = [Net.DNS]::GetHostEntry($VM.Name) } 
		catch { $IPAddress = $IPAddress }
	if ($HostEntry) { 
		$IPAddresses.Add($HostEntry.AddressList[0].IPAddressToString) | Out-Null
		$isIPFound = $true
	}

	if ($isIPFound) {
	
		$IPAddresses = $IPAddresses | Select-Object -Unique
		if ($IPAddresses.GetType().Name -eq "String") {
			$Temp = $IPAddresses
			$IPAddresses = New-Object System.Collections.ArrayList
			$IPAddresses.Add($Temp) | Out-Null
		}
	
		foreach ($IPAddress in $IPAddresses) {
			$isIPUP = Test-Connection -ComputerName $IPAddress -Count 1 -Quiet -ErrorAction:SilentlyContinue
			if ($isIPUP) { $isServerUP = $true }
		}
		
		if ($isServerUP -eq $false) {
			$TeamUplink = Get-INGVMUplink -VM $VM
			Write-INGLog -Message ("{0}({1}) is down on {2}:{3}" -f $VM.Name, (ArrayToString -Array $IPAddresses), $VM.VMHost.Name.Split(".")[0], $TeamUplink[1]) -Color Cyan
		} else {
			Write-INGLog -Message ("{0}({1}) is up on {2}" -f $VM.Name, (ArrayToString -Array $IPAddresses), $VM.VMHost.Name.Split(".")[0]) -Color Cyan
		}
	} else {
		Write-INGLog -Message ("{0}, cannot resolve IPAddress or IPAddress not found" -f $VM.Name) -Color Cyan
	}
}

UninitializeEnvironment