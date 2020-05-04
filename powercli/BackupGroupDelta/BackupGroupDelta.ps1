# Subject     : Sets backup groups according to NetApp controllers
# Prepared by : Ozan Orçunus
# Script Name : BackupGroupDelta.ps1
# Version     : 1.00

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)][String]$vCenter,
		[Parameter(Mandatory=$true)][String]$Site,
		[Switch]$NoAnnotation,
		[Switch]$NoExcel )
		
function InitializeEnvironment {
	Import-Module -Name INGPSModule -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "BackupGroupDelta"
	Connect-INGvCenter -vCenter $vCenter
}

function UninitializeEnvironment {
	Disconnect-INGvCenter -vCenter $vCenter
	Uninitialize-INGScript
}

function New-BackupGroup {
    param ( [Parameter(Mandatory=$true)][string]$Name )
	
	$BG = "" | Select-Object Name,Size,VMs,VMCount,Controlers,CurrentControlerSize,ControlerSizes,Datastores,CurrentDatastoreSize,DatastoreSizes
	$BG.Name                 = $Name
	$BG.Size                 = 0
	$BG.CurrentDatastoreSize = 0
	$BG.CurrentControlerSize = 0
	$BG.VMCount              = 0
	$BG.VMs                  = New-Object System.Collections.ArrayList
	$BG.Datastores           = New-Object System.Collections.ArrayList
	$BG.DatastoreSizes       = New-Object System.Collections.ArrayList
	$BG.Controlers           = New-Object System.Collections.ArrayList
	$BG.ControlerSizes       = New-Object System.Collections.ArrayList
	
	$BG = $BG | Add-Member ScriptMethod AddVM {
		param ( [string]$PVM,[int]$PSize,[string]$PDatastore)
		if (!$PVM -or !$PSize -or !$PDatastore) { return }
		
		$VMindex= $this.VMs.Add($PVM)
		$this.Size += $PSize
		$this.VMCount ++
		
		$PControler = $PDatastore.Split(".")[3]
		
		$indexDS = $this.Datastores.IndexOf($PDatastore)
		$indexCO = $this.Controlers.IndexOf($PControler)
		if (($indexCO -lt 0) -or ($indexDS -lt 0)) {
			Write-INGLog -Message ("{0} cannot be found in BackupGroup {1}" -f $PDatastore,$this.Name) -Color "RED"
		} else {
			$this.DatastoreSizes[$indexDS] = $this.DatastoreSizes[$indexDS] + $PSize
			$this.ControlerSizes[$indexCO] = $this.ControlerSizes[$indexCO] + $PSize
		}
	} -PassThru
		
	$BG = $BG | Add-Member ScriptMethod PopulateDatastoresAndControlers {
		param ( [System.Array]$PDatastores)
		foreach ($PDatastore in $PDatastores) {
			$indexDS = $this.Datastores.Add($PDatastore.Name)
			$indexDS = $this.DatastoreSizes.Add(0)
			
			$PControler = $PDatastore.Name.Split(".")[3]
			if ($this.Controlers.Contains($PControler) -eq $false) {
				$indexCO = $this.Controlers.Add($PControler)
				$indexCO = $this.ControlerSizes.Add(0)
			}
		}	
	} -PassThru
	
	$BG = $BG | Add-Member ScriptMethod GetDatastoreSize {
		param ( [string]$PDatastore)
		$index = $this.Datastores.IndexOf($PDatastore)
		$this.CurrentDatastoreSize = $this.DatastoreSizes[$index]
		return $this.CurrentDatastoreSize
	} -PassThru
	
	$BG = $BG | Add-Member ScriptMethod GetControlerSize {
		param ( [string]$PDatastore)
		$PControler = $PDatastore.Split(".")[3]
		$index = $this.Controlers.IndexOf($PControler)
		$this.CurrentControlerSize = $this.ControlerSizes[$index]
		return $this.CurrentControlerSize
	} -PassThru
		
	return $BG
}

function BackupVMSize {
	param ( [Parameter(Mandatory=$true)][VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]$PVM )
	$TotalSize = 0
	$HardDisks = Get-HardDisk -VM $PVM | Where-Object { $_.Persistence -eq "Persistent" }
	foreach ($HardDisk in $HardDisks) {
		$TotalSize += [Math]::Round($HardDisk.CapacityKB / 1048576)
	}
	return $TotalSize
}

function GetVMType {
	param ( [Parameter(Mandatory=$true)][VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]$PVM )
	$OSFullName = $PVM.ExtensionData.Config.GuestFullName
	if ($OSFullName -match "Windows") { return "Windows" }
		else { return "Linux" }
}

function GetExistingBackupGroup {
	param (	[string]$PAnnotation)
	foreach ($BackupGroup in $Global:BackupGroups) {
		if ($BackupGroup.Name -eq $PAnnotation) { return $BackupGroup }
	}
	return $null
}

function InsertTableRow {
	param ([string]$PVMName,[int]$PSize,[string]$PGroup,[string]$PControler,[string]$PDatastore,[int]$PVMSize,[string]$PCommand)
	$OleDbConn    = New-Object "System.Data.OleDb.OleDbConnection"
	$OleDbCmd     = New-Object "System.Data.OleDb.OleDbCommand"
	$OleDbConn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$Global:OutFile;Extended Properties=""Excel 12.0 Xml;HDR=YES"";"
	$OleDbConn.Open()
	$OleDbCmd.Connection = $OleDbConn
	$OleDbCmd.CommandText = ("Insert into [Backup$] Values ('{0}','{1}',{2},'{3}','{4}','{5}',{6},'{7}')" -f $Global:DefaultVIServer.Name,$PVMName,$PSize,$PGroup,$PControler,$PDatastore,$PVMSize,$PCommand)
	$OleDbCmd.ExecuteNonQuery() | Out-Null
	$OleDbConn.Close()
}

function ComputeBackupGroups {
	param (	[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl[]]$VMs)
	
	foreach ($VM in $VMs) {
		$VM_Annotation = $VM.CustomFields["BackupGroup"]
		if ($VM_Annotation -eq "<Not Set>") { $VM_Annotation = $Null }
		
		if (!$VM_Annotation) { $Global:MissingVMs += $VM; Write-Host $VM.Name -NoNewline -ForegroundColor Red; continue }
		if ($VM_Annotation -eq "NoBackup") { Write-Host $VM.Name -NoNewline -ForegroundColor Yellow; continue }
		if ($VM_Annotation -match "VMWARENQ") { Write-Host $VM.Name -NoNewline -ForegroundColor DarkYellow; continue }
		if ($VM_Annotation -match "Gecici") { Write-Host $VM.Name -NoNewline -ForegroundColor DarkYellow; continue }
		
		$VM_Name        = $VM.Name
		$VM_Size        = BackupVMSize -PVM $VM
		$VM_Datastore   = Get-INGDatastoreFromVM -VMName $VM_Name
		$VM_Controler   = $VM_Datastore.Split(".")[3]
		$VM_BackupGroup = GetExistingBackupGroup -PAnnotation $VM_Annotation
		$VM_BackupGroup.AddVM($VM_Name,$VM_Size,$VM_Datastore)
		Write-Host $VM.Name -NoNewline
	}
	Write-Host
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

InitializeEnvironment

$AllDatastores  = Get-Datastore
$AllVMs         = Get-Datacenter -Name $Site* | Get-VM
$Count          = 0
$Global:BackupGroups = @()
$Global:MissingVMs   = @()

if ($vCenter -eq "PREVC") {
	$Global:BackupGroups += New-BackupGroup -Name "PRE_VMWARE_01"
	$Global:BackupGroups += New-BackupGroup -Name "PRE_VMWARE_02"
	$Global:BackupGroups += New-BackupGroup -Name "PRE_VMWARE_03"
	$Global:BackupGroups += New-BackupGroup -Name "PRE_VMWARE_04"
	$Global:BackupGroups += New-BackupGroup -Name "PRE_VMWARE_05"
	$Global:BackupGroups += New-BackupGroup -Name "PRE_VMWARE_06"
	$Global:BackupGroups += New-BackupGroup -Name "PRE_VMWARE_07"
	$Global:BackupGroups += New-BackupGroup -Name "PRE_VMWARE_08"
	$Global:BackupGroups += New-BackupGroup -Name "PRE_VMWARE_09"
	$Global:BackupGroups += New-BackupGroup -Name "PRE_VMWARE_10" 
}
if (($vCenter -eq "DC1VC") -or ($vCenter -eq "dc1vm")) {
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_01"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_02"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_03"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_04"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_05"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_06"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_07"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_08"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_09"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_10"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_11"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_12"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_13"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_14"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_15"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_16"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_17"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_18"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_19"
	$Global:BackupGroups += New-BackupGroup -Name "DC1_VMWARE_20"
}
if (($vCenter -eq "DC2VC") -or ($vCenter -eq "dc2vm")) {
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_01"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_02"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_03"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_04"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_05"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_06"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_07"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_08"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_09"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_10"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_11"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_12"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_13"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_14"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_15"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_16"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_17"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_18"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_19"
	$Global:BackupGroups += New-BackupGroup -Name "DC2_VMWARE_20"
}

Write-INGLog -Message "Populating Datastores & Controllers" -Color "GREEN"
foreach ($BackupGroup in $Global:BackupGroups) { $BackupGroup.PopulateDatastoresAndControlers($AllDatastores) }
Write-INGLog -Message "Computing Backup Groups and Getting Missing VMs" -Color "GREEN"
ComputeBackupGroups -VMs $AllVMs 

foreach ($MissingVM in $Global:MissingVMs) {
	
	$VM_Size          = BackupVMSize -PVM $MissingVM
	$VM_Type          = GetVMType -PVM $MissingVM
	$VM_Datastore     = Get-INGDatastoreFromVM -VMName $MissingVM.Name
	$VM_Controler     = $VM_Datastore.Split(".")[3]
	$VM_Name          = $MissingVM.Name
	$VM_Version       = $MissingVM.ExtensionData.Config.Version
	$DatastoreSizeMin = 1000000
	$ControlerSizeMin = 1000000
	
	Write-INGLog -Message ("Setting BackupGroup for {0}-{1}: " -f $VM_Name, $VM_Controler) -Color "CYAN" -NoReturn
	
	foreach ($BackupGroup in $Global:BackupGroups) {
		$DatastoreSize = $BackupGroup.GetDatastoreSize($VM_Datastore)
		$ControlerSize = $BackupGroup.GetControlerSize($VM_Datastore)
		if ($DatastoreSizeMin -gt $DatastoreSize ) { $DatastoreSizeMin = $DatastoreSize }
		if ($ControlerSizeMin -gt $ControlerSize ) { $ControlerSizeMin = $ControlerSize }
	}
	
	$BackupGroup = $Global:BackupGroups | Sort-Object CurrentControlerSize,CurrentDatastoreSize,Size,Name | Select-Object -First 1
	$BackupGroup.AddVM($VM_Name,$VM_Size,$VM_Datastore)
	if ($VM_Type -eq "Windows") { $Command = ("bpplclients {0} -add {1} {2} windows7Server64Guest;sleep 3;" -f $BackupGroup.Name,$VM_Name,$VM_Version) }
		else { $Command = ("bpplclients {0} -add {1} {2} rhel5_64Guest;sleep 3;" -f $BackupGroup.Name,$VM_Name,$VM_Version) }
	Write-INGLog -Message ("{0}" -f $BackupGroup.Name) -NoDateLog
	
	if (!$NoExcel)      { InsertTableRow $MissingVM.Name $VM_Size $Global:BackupGroup.Name $VM_Controler $VM_Datastore $BackupGroup.Size $Command }
	if (!$NoAnnotation) { $MissingVM.ExtensionData.setCustomValue("BackupGroup",$BackupGroup.Name) }
}

UninitializeEnvironment


# BackupGruplarını aluştur, tüm gruplara tüm datastoreları ve controller'ları ekle
# Gruplara göre döngüye sok, o datastore'un tüm gruplarda kaç kere tekrar ettiğini bul, minimumunu al
# Grupları sort et, RepeatCount, Size, VMCount'a göre
# Gelen ilk gruba VM'i dahil et. Counter'ları artır. Sonraki VM'e geç.