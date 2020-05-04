# *********************************************************************
#
# Powershell script that rescans for HBA devices simultaneously.
#
# ASSUMPTIONS:
# VICredentialStore already created and ready to use
# 
# *********************************************************************

$Cred = Get-VICredentialStoreItem -File D:\Library\Tools\Credentials\Cred-VCENTER.xml
$VIServer = Connect-VIServer -Server VCENTER -User $Cred.User -Password $Cred.Password

$VMHosts = Get-Cluster -Name "" | Get-VMHost | Where-Object { $_.PowerState -eq "PoweredOn" }

foreach ($VMHost in $VMHosts) {
	$Job = Start-Job -ScriptBlock { 
		Add-PSSnapin VMware.VimAutomation.Core 
		Connect-VIServer -Server $Args[0] -User $Args[1].User -Password $Args[1].Password
		$VMHostStorage = Get-VMHostStorage -VMHost (Get-VMHost -Name $Args[2])
		$VMHostStorage_View = Get-View -Id $VMHostStorage.Id
		$VMHostStorage_View.RescanAllHba()
		$VMHostStorage_View.RescanVmfs()
		Disconnect-VIServer -Confirm:$false 
	} -ArgumentList @($VIServer.Name, $Cred, $VMHost.Name)
}

Disconnect-VIServer -Confirm:$false

# Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs