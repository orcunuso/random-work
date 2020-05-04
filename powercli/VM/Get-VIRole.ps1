#Get-Module -ListAvailable
#Import-Module viToolkitExtensions -PassThru

$Role = Get-TkeRoles | Where { $_.Name -eq "NetApp VSC Optimization" }
$StringPrivs = ""
$Count = 1

foreach ($strPriv in $Role.Privilege) {
	if ($Count -eq $Role.Privilege.Count) {
		$StringPrivs = $StringPrivs + '"' + $strPriv + '"'
	} 
	else {
		$StringPrivs = $StringPrivs + '"' + $strPriv + '"' + ',' 
	}
	$Count++
}

Write-Output $StringPrivs | Out-File D:\VIRole_NetappOptimization.txt

#New-TkeRole -name "NetApp VSC Optimization" -privIds "VirtualMachine.Interact.PowerOn","VirtualMachine.Interact.PowerOff"
#Set-TkeRole -name $Role.Name -privIds "VirtualMachine.Interact.PowerOn","VirtualMachine.Interact.PowerOff"