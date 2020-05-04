function Create-AntiAffinityDRSRules {

<# 
.SYNOPSIS  Configure DRS anti-affinity rules
.DESCRIPTION 
  The function will list the VMs in a DRS cluster and group them according to their names
  If an anti-affinity rule does not exist for the VM group, it will create the rule and add the VMs
  If a rule exists but does not include the VM, it will add related VMs to the rule 
.NOTES
  Created by: Ozan Orcunus
.PARAMETER Cluster
  Cluster name for which to create DRS anti-affinity rules
.EXAMPLE
  PS> Create-AntiAffinityDRSRules -Cluster ClusterName
#>

	param ( [Parameter(Mandatory=$true) ][string]$DRSCluster)
	
	function Check-DRSRuleforVM {
		param ( [Parameter(Mandatory=$true)][Object]$VM,
				[Parameter(Mandatory=$true)][Object]$Rule)

		if ($Rule.VMIds.Contains($VM.Id)) { return $true }
			else { return $false }
	}

	function Create-DRSRule {
		param ( [Parameter(Mandatory=$true)][Object]$Cluster,
				[Parameter(Mandatory=$true)][Object[]]$VMs,
				[Parameter(Mandatory=$true)][string]$Rule)

		$spec = New-Object VMware.Vim.ClusterConfigSpecEx
		$spec.rulesSpec = New-Object VMware.Vim.ClusterRuleSpec[] (1)
		$spec.rulesSpec[0] = New-Object VMware.Vim.ClusterRuleSpec
		$spec.rulesSpec[0].operation = "add"
		$spec.rulesSpec[0].info = New-Object VMware.Vim.ClusterAntiAffinityRuleSpec
		$spec.rulesSpec[0].info.enabled = $true
		$spec.rulesSpec[0].info.name = $Rule
		$spec.rulesSpec[0].info.userCreated = $true
		$spec.rulesSpec[0].info.vm = ($VMs | Get-View) | %{$_.moref} 
		$morTask = $Cluster.ExtensionData.ReconfigureComputeResource_Task($spec, $true)
		$vimTask = Get-Task -Id ("Task-{0}" -f $morTask.Value)
		$vimTask.ExtensionData.waitForTask($morTask)
	}

	function Modify-DRSRule {
		param ( [Parameter(Mandatory=$true)][Object]$Cluster,
				[Parameter(Mandatory=$true)][Object[]]$VMs,
				[Parameter(Mandatory=$true)][Object]$Rule)

		$spec = New-Object VMware.Vim.ClusterConfigSpecEx
		$spec.rulesSpec = New-Object VMware.Vim.ClusterRuleSpec[] (1)
		$spec.rulesSpec[0] = New-Object VMware.Vim.ClusterRuleSpec
		$spec.rulesSpec[0].operation = "edit"
		$spec.rulesSpec[0].info = New-Object VMware.Vim.ClusterAntiAffinityRuleSpec
		$spec.rulesSpec[0].info.key = $Rule.Key
		$spec.rulesSpec[0].info.enabled = $true
		$spec.rulesSpec[0].info.name = $Rule.Name
		$spec.rulesSpec[0].info.userCreated = $true
		$spec.rulesSpec[0].info.vm = ($VMs | Get-View) | %{$_.moref} 
		$morTask = $Cluster.ExtensionData.ReconfigureComputeResource_Task($spec, $true)
		$vimTask = Get-Task -Id ("Task-{0}" -f $morTask.Value)
		$vimTask.ExtensionData.waitForTask($morTask)
	}

	$int_suffixLength = 2
	$obj_Cluster = Get-Cluster -Name $DRSCluster
	$obj_VMFullNames  = $obj_Cluster | Get-VM | Sort-Object Name
	
	foreach ($obj_VM in $obj_VMFullNames) {

		Write-Host ("{0}: " -f $obj_VM.Name) -NoNewline -ForegroundColor Cyan
		$str_VMShortName = $obj_VM.Name.Substring(0,$obj_VM.Name.Length - $int_suffixLength)	
		$obj_SimilarVMs  = $obj_VMFullNames | Where-Object {$_.Name -match $str_VMShortName}
		$obj_SimilarVMs  = $obj_SimilarVMs | Where-Object {$_.Name.Length -eq $obj_VM.Name.Length}
		
		if ($obj_SimilarVMs.Count -eq 1) { 
			Write-Host ("No additional VMs found to create an anti-affinity DRS rule")
			Continue 
		}
		
		$str_DRSRule = ("{0}_Seperate" -f $str_VMShortName)
		$obj_DRSRule = $null
		$obj_DRSRule = Get-DrsRule -Name $str_DRSRule -Cluster $obj_Cluster -ErrorAction:SilentlyContinue	
		if ($obj_DRSRule) {
			if (Check-DRSRuleforVM -VM $obj_VM -Rule $obj_DRSRule) {
				Write-Host ("{0} already exists in DRS rule {1}" -f $obj_VM.Name, $obj_DRSRule.Name) -ForegroundColor Green
			} else {
				Write-Host ("{0} does not exist in DRS rule {1}, adding related VMs into it" -f $obj_VM.Name, $obj_DRSRule.Name) -ForegroundColor Cyan
				Modify-DRSRule -Cluster $obj_Cluster -VMs $obj_SimilarVMs -Rule $obj_DRSRule
			}
		} else {
			Write-Host ("No DRS Rule exists, creating {0} and adding related VMs into it" -f $str_DRSRule) -ForegroundColor Yellow
			Create-DRSRule -Cluster $obj_Cluster -VMs $obj_SimilarVMs -Rule $str_DRSRule
		}
	}
}