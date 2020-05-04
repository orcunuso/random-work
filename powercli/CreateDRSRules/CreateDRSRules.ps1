# Project     : Create DRS Rules
# Prepared by : Ozan Orçunus
#

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)][string]$vCenter,
		[Parameter(Mandatory=$true)][string]$Cluster,
		[Switch]$Test )

function InitializeEnvironment {
	Import-Module -Name INGPSModule -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "CreateDRSRules"
	Connect-INGvCenter -vCenter $vCenter
}

function UninitializeEnvironment {
	Uninitialize-INGScript
	Disconnect-INGvCenter -vCenter $vCenter
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

InitializeEnvironment

$VMCluster = Get-Cluster -Name $Cluster
$VMs = $VMCluster | Get-VM | Sort-Object Name

foreach ($VM in $VMs | Select -First 3) {

	Write-INGLog -Message ("{0}: " -f $VM.Name) -NoReturn
	$strShortName = $VM.Name.Substring(0,$VM.Name.Length - 2)	
	$SimilarVMs   = $VMs | Where-Object {$_.Name -match $strShortName}
	
	if ($SimilarVMs.Count -eq 1) {
		Write-INGLog -Message ("No Similar VM found") -NoDateLog
		Continue
	}
	
	$DRSRuleName = ("{0}_Sep" -f $strShortName)
	$DRSRule = $null
	$DRSRule = Get-DrsRule -Name $DRSRuleName -Cluster $VMCluster -ErrorAction:SilentlyContinue
	
	if ($DRSRule) {
		Write-INGLog -Message ("DRS Rule already exists; {0}" -f $DRSRule.Name) -NoDateLog
		Continue
	}
	
	try {
		if ($Test) {
			Write-INGLog -Message ("New-DrsRule -Name {0} -Cluster {1} -Enabled:true -KeepTogether:true -VM {2} -Confirm:$false" -f $DRSRuleName, $VMCluster, $SimilarVMs) -NoDateLog
		} else {
			Write-INGLog -Message ("Creating DRS Rule {0}" -f $DRSRuleName) -NoDateLog -Color Yellow
			$spec = New-Object VMware.Vim.ClusterConfigSpecEx
			$spec.rulesSpec = New-Object VMware.Vim.ClusterRuleSpec[] (2)
			$spec.rulesSpec[0] = New-Object VMware.Vim.ClusterRuleSpec
			$spec.rulesSpec[0].operation = "add"
			$spec.rulesSpec[0].info = New-Object VMware.Vim.ClusterAntiAffinityRuleSpec            
			$spec.rulesSpec[0].info.enabled = $true
			$spec.rulesSpec[0].info.name = $DRSRuleName
			$spec.rulesSpec[0].info.userCreated = $true
			$spec.rulesSpec[0].info.vm = ($SimilarVMs | Get-View) | %{$_.moref}  
			$Task = (Get-View -Id $VMCluster.id).ReconfigureComputeResource_Task($spec, $true)
			Start-Sleep -Seconds 3
		}
	} catch {
		$ErrorMessage = $_.Exception.Message
		Write-INGLog -Message $ErrorMessage -Severity "ERROR"
		UpdateTableRow -UpdateField "Status" -UpdateValue "Error" -DatastoreName $Datastore.Name
	}
}

UninitializeEnvironment

# [END] ....................................................................................














