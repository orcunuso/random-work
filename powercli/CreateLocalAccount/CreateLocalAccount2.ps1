# Project     : Creates local accounts on ESX Servers and assigns ReadOnly permissions
# Prepared by : Ozan Orçunus
#

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)]  [string]$vCenter,
		[Parameter(Mandatory=$false)] [string]$Cluster,
		[Parameter(Mandatory=$true)]  [string]$AccountName,  #svchpirs_esxi
		[Switch]$Switch )

function InitializeEnvironment {
	Import-Module -Name INGPSModule -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "CreateLocalAccount"
	Connect-INGvCenter -vCenter $vCenter
}

function UninitializeEnvironment {
	Uninitialize-INGScript
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

InitializeEnvironment

if ($Cluster) { $ESXs = Get-Cluster -Name $Cluster | Get-VMHost | Where {$_.PowerState -eq "PoweredOn"} | Sort Name | Select-Object -First 1 }
	else { $ESXs = Get-VMHost | Where {$_.PowerState -eq "PoweredOn"} | Sort Name }
Disconnect-INGvCenter -vCenter $vCenter

foreach ($ESX in $ESXs) {
	
	$ESXVIServer = $null
	$Account     = $null
	$Role        = $null
	$Permission  = $null
	$ESXVMHost   = $null
	
	$ESXVIServer = Connect-INGESXServer -ESXServer $ESX.Name
	if ($ESXVIServer) {
		$Account = Get-VMHostAccount -Id $AccountName -Server $ESXVIServer -ErrorAction:SilentlyContinue
		if ($Account) {
			Write-INGLog ("Account:{0} already exists on {1}" -f $Account.Id, $ESXVIServer.Name)
			Disconnect-VIServer -Server $ESXVIServer -Confirm:$false
			continue
		}
		try {
			$Account    = New-VMHostAccount -UserAccount -GrantShellAccess -Id $AccountName -Description $AccountName -Password sss -Server $ESXVIServer -Confirm:$false
			$Role       = Get-VIRole -Name ReadOnly -Server $ESXVIServer
			$ESXVMHost  = Get-VMHost
			$Permission = New-VIPermission -Entity $ESXVMHost -Principal $Account -Role $Role -Propagate:$true -Confirm:$false
		} catch {
			$ErrorMessage = $_.Exception.Message
			Write-INGLog -Message $ErrorMessage -Color RED
		}
		if ($Permission) {
			Write-INGLog -Message ("Permission created between account:{0} and role:{1}" -f $Account.Id, $Role.Name)
		} else {
			Write-INGLog ("Failed to create permission between account:{0} and role:{1}" -f $Account.Id, $Role.Name)
		}
		Disconnect-VIServer -Server $ESXVIServer -Confirm:$false
	} else {
		Write-INGLog -Message ("Failed to connect to {0}" -f $ESX.Name) -Color Red
		continue
	}
}

UninitializeEnvironment

# [END] ....................................................................................