function Get-ObservedIPRange {
       param(
            [Parameter(Mandatory=$true,ValueFromPipeline=$true,HelpMessage="Physical NIC from Get-VMHostNetworkAdapter")]
            [VMware.VimAutomation.Client20.Host.NIC.PhysicalNicImpl]
            $Nic
    )
 
    process {
        $hostView = Get-VMHost -Id $Nic.VMHostId | Get-View -Property ConfigManager
        $ns = Get-View $hostView.ConfigManager.NetworkSystem
        $hints = $ns.QueryNetworkHint($Nic.Name)
 
        foreach ($hint in $hints) {
            foreach ($subnet in $hint.subnet) {
                $observed = New-Object -TypeName PSObject
                $observed | Add-Member -MemberType NoteProperty -Name Device -Value $Nic.Name
                $observed | Add-Member -MemberType NoteProperty -Name VMHostId -Value $Nic.VMHostId
                $observed | Add-Member -MemberType NoteProperty -Name IPSubnet -Value $subnet.IPSubnet
                $observed | Add-Member -MemberType NoteProperty -Name VlanId -Value $subnet.VlanId
                Write-Output $observed
            }
        }
    }
}

Get-VMHost -Name DC1ESXMT01.mydomain.local | Get-VMHostNetworkAdapter | Where { $_.Name -eq "vmnic1" } | Get-ObservedIPRange
 
# Example use:
# Get-VMHost esx01a.vmworld.com | Get-VMHostNetworkAdapter | Where { $_.Name -eq "vmnic1" } | Get-ObservedIPRange
