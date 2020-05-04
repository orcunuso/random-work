# Project     : Creates local accounts on ESX Servers and assigns ReadOnly permissions
# Prepared by : Ozan Orçunus
#

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)]  [string]$vCenter,
		[Parameter(Mandatory=$false)] [string]$Cluster,
		[Parameter(Mandatory=$true)]  [string]$AccountName)

function New-Credential {
	[CmdletBinding()]
	param ( [Parameter(Mandatory=$true)][System.Object]$CredStore, 
			[Parameter(Mandatory=$true)][String]$CredName)
	
	$CredPass  = ConvertTo-SecureString ($CredStore | Where {$_.Host -eq $CredName}).Password -AsPlainText -Force
	$CredUser  = ($CredStore | Where {$_.Host -eq $CredName}).User
	$Cred      = New-Object System.Management.Automation.PSCredential ($CredUser, $CredPass)
	return $Cred
}

function Get-SecurePass {
	[CmdletBinding()]
    param ( [Parameter(Mandatory=$true)][string]$SecurePassword)
	
    $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($SecurePassword)
    $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)
    return $Password
}

$CredStoreFile = "D:\Users\oorcunus\Documents\Scripts\CredStore\OZAN-Store.xml"
$CredStore     = Get-VICredentialStoreItem -File $CredStoreFile
$VCenterCred   = New-Credential -CredStore $CredStore -CredName "VCENTER"
$ESXiCred      = New-Credential -CredStore $CredStore -CredName "ESXi"
$UserCred      = Get-VICredentialStoreItem -File $CredStoreFile -Host "HAWK"

$VIServer    = Connect-VIServer -Server $vCenter -Credential $VCenterCred -WarningAction:SilentlyContinue
if ($Cluster) { 
	$ESXs = Get-Cluster -Name $Cluster | Get-VMHost | Where {$_.PowerState -eq "PoweredOn"} | Sort Name
} else { 
	$ESXs = Get-VMHost | Where {$_.PowerState -eq "PoweredOn"} | Sort Name 
}
Disconnect-VIServer -Server $vCenter -Confirm:$false

foreach ($ESX in $ESXs) {
	
	$ESXVIServer = $null
	$Account     = $null
	$Role        = $null
	$Permission  = $null
	$ESXVMHost   = $null
	
	$ESXVIServer = Connect-VIServer -Server $ESX.Name -Credential $ESXiCred -WarningAction:SilentlyContinue -ErrorAction:SilentlyContinue
	if ($ESXVIServer) {
		$Account = Get-VMHostAccount -Id $AccountName -Server $ESXVIServer -ErrorAction:SilentlyContinue
		if ($Account) {
			Write-Host ("Account:{0} already exists on {1}" -f $Account.Id, $ESXVIServer.Name)
			Disconnect-VIServer -Server $ESXVIServer -Confirm:$false
			continue
		}
		try {
			$Account    = New-VMHostAccount -UserAccount -GrantShellAccess -Id $AccountName -Description $AccountName -Password $UserCred.Password -Server $ESXVIServer -Confirm:$false
			$Role       = Get-VIRole -Name ReadOnly -Server $ESXVIServer
			$ESXVMHost  = Get-VMHost
			$Permission = New-VIPermission -Entity $ESXVMHost -Principal $Account -Role $Role -Propagate:$true -Confirm:$false
			Write-Host ("Permission created between account:{0} and role:{1}" -f $Account.Id, $Role.Name)
		} catch {
			$ErrorMessage = $_.Exception.Message
			Write-Host $ErrorMessage -ForegroundColor Red
		}
		
		Disconnect-VIServer -Server $ESXVIServer -Confirm:$false
	} else {
		Write-Host ("Failed to connect to {0}" -f $ESX.Name) -ForegroundColor Red
	}
}

# [END] ....................................................................................