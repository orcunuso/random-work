$VMs = Get-Datastore -Name *.2* | Where-Object { $_.PowerState -eq "PoweredOn" }
$ping = New-Object System.Net.NetworkInformation.Ping

foreach ($VM in $VMs) {
	Write-Host $VM.Name : -NoNewLine
	
	try { $PingResult = $ping.Send($VM.Name) }
		catch { Write-Host "Error trying to ping $VM" }
	
	if (!$Error) {
		Write-Host $PingResult.Status
	}
	
	$Error.Clear()
}
