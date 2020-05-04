$Date = Get-Date
$HAVMrestartold = 8
$HAEvents = Get-VIEvent -maxsamples 100000 -Start ($Date).AddDays(-$HAVMrestartold) -type warning | Where {$_.FullFormattedMessage -match "vSphere HA restarted"} | select CreatedTime,FullFormattedMessage |sort CreatedTime -Descending



#OneLiner:

Get-VIEvent -MaxSamples 100000 -Start (Get-Date).AddDays(-8) -Type Warning | Where-Object {$_.FullFormattedMessage -match "vSphere HA restarted"} | Select-Object CreatedTime,FullFormattedMessage | Sort-Object CreatedTime -Descending | FT -Autosize