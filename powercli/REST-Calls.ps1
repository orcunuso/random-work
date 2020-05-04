$Global:DefaultApiURL = $null

function Connect-REST_VIServer {
    param ( [Parameter(Mandatory=$true)][String]$VIServer,
            [Parameter(Mandatory=$true)][String]$userName,
            [Parameter(Mandatory=$true)][String]$userPass )

    $secPass = ConvertTo-SecureString $userPass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($userName, $secPass)
    $Global:DefaultApiURL = ("https://{0}/rest" -f $VIServer)
    $ApiURL = ("{0}/com/vmware/cis/session" -f $Global:DefaultApiURL)
    $headers = @{
        "Content-Type"="application/json";
        "Accept"="application/json";
        "vmware-use-header-authn"="TestValue2" }
    $response = Invoke-RestMethod -Uri $ApiURL -Method Post -Credential $cred -Headers $headers
    $sessionID = $response.value
    return $sessionID
}

function Disconnect-REST_VIServer {
    param ( [Parameter(Mandatory=$true)][String]$sessionID )

    $ApiURL = ("{0}/com/vmware/cis/session" -f $Global:DefaultApiURL)
    $headers = @{
        "Content-Type"="application/json";
        "Accept"="application/json";
        "vmware-api-session-id"=$sessionID }
    $response = Invoke-RestMethod -Uri $ApiURL -Method Delete -Headers $headers
    $Global:DefaultApiURL = $null
}

function Get-REST_VM {
    param ( [Parameter(Mandatory=$true)][String]$vmName,
            [Parameter(Mandatory=$true)][String]$sessionID )

    $ApiURL = ("{0}/vcenter/vm" -f $Global:DefaultApiURL)
    $headers = @{
        "Content-Type"="application/json";
        "Accept"="application/json";
        "vmware-api-session-id"=$sessionID }
    $body = @{"filter.names"=$vmName}
    $response = Invoke-RestMethod -Uri $ApiURL -Method Get -Headers $headers -Body $body
    $vmID = $response.value.vm
    return $vmID
}

function Start-REST_VM {
    param ( [Parameter(Mandatory=$true)][String]$vmID,
            [Parameter(Mandatory=$true)][String]$sessionID )

    $ApiURL = ("{0}/vcenter/vm/{1}/power/start" -f $Global:DefaultApiURL, $vmID)
    $headers = @{
        "Content-Type"="application/json";
        "Accept"="application/json";
        "vmware-api-session-id"=$sessionID }
    $response = Invoke-RestMethod -Uri $ApiURL -Method Post -Headers $headers
}

function Stop-REST_VM {
    param ( [Parameter(Mandatory=$true)][String]$vmID,
            [Parameter(Mandatory=$true)][String]$sessionID )

    $ApiURL = ("{0}/vcenter/vm/{1}/power/stop" -f $Global:DefaultApiURL, $vmID)
    $headers = @{
        "Content-Type"="application/json";
        "Accept"="application/json";
        "vmware-api-session-id"=$sessionID }
    $response = Invoke-RestMethod -Uri $ApiURL -Method Post -Headers $headers
}

$VIServer = "dc2vcsa02.mydomain.local"
$userName = "viadmin@vsphere65.local"
$userPass = "Ssa@dm6vm55"

$WebClient = New-Object System.Net.WebClient
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
$Output = $WebClient.DownloadString("https://{0}" -f $VIServer)

#$sessionID = Connect-REST_VIServer -VIServer $VIServer -userName $userName -userPass $userPass
#$vmID = Get-REST_VM -vmName "PHOTON01" -sessionID $sessionID
#Start-REST_VM -vmID $vmID -sessionID $sessionID
#Stop-REST_VM -vmID $vmID -sessionID $sessionID
#Disconnect-REST_VIServer -sessionID $sessionID