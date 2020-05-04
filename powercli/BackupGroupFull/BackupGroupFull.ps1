# Subject     : Sets backup groups according to NetApp controllers
# Prepared by : Ozan Orçunus
# Script Name : BackupGroupFull.ps1
# Version     : 1.00

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)][String]$vCenter,
		[Parameter(Mandatory=$true)][String]$Site,
		[Switch]$NoAnnotation,
		[Switch]$NoExcel )
		
function InitializeEnvironment {
	Import-Module -Name INGPSModule -WarningAction:SilentlyContinue
	Initialize-INGScript -ScriptName "BackupGroupFull"
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

function InsertTableRow {
	param ([String]$PVMName,[int]$PSize,[string]$PGroup,[string]$PControler,[string]$PDatastore,[int]$PVMSize,[string]$PCommand)
	$OleDbConn    = New-Object "System.Data.OleDb.OleDbConnection"
	$OleDbCmd     = New-Object "System.Data.OleDb.OleDbCommand"
	$OleDbConn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$Global:OutFile;Extended Properties=""Excel 12.0 Xml;HDR=YES"";"
	$OleDbConn.Open()
	$OleDbCmd.Connection = $OleDbConn
	$OleDbCmd.CommandText = ("Insert into [Backup$] Values ('{0}','{1}',{2},'{3}','{4}','{5}',{6},'{7}')" -f $Global:DefaultVIServer.Name,$PVMName,$PSize,$PGroup,$PControler,$PDatastore,$PVMSize,$PCommand)
	$OleDbCmd.ExecuteNonQuery() | Out-Null
	$OleDbConn.Close()
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

InitializeEnvironment

$BackupGroups   = @()
$AllDatastores  = Get-Datastore
$AllVMs         = Get-Datacenter -Name $Site* | Get-VM
$Count          = 0

switch ($vCenter) {
	"PREVC"
		{
			$BackupGroups += New-BackupGroup -Name "PRE_VMWARE_01"
			$BackupGroups += New-BackupGroup -Name "PRE_VMWARE_02"
			$BackupGroups += New-BackupGroup -Name "PRE_VMWARE_03"
			$BackupGroups += New-BackupGroup -Name "PRE_VMWARE_04"
			$BackupGroups += New-BackupGroup -Name "PRE_VMWARE_05"
			$BackupGroups += New-BackupGroup -Name "PRE_VMWARE_06"
			$BackupGroups += New-BackupGroup -Name "PRE_VMWARE_07"
			$BackupGroups += New-BackupGroup -Name "PRE_VMWARE_08"
			$BackupGroups += New-BackupGroup -Name "PRE_VMWARE_09"
			$BackupGroups += New-BackupGroup -Name "PRE_VMWARE_10"
		}
	"DC1VC"
		{
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_01"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_02"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_03"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_04"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_05"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_06"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_07"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_08"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_09"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_10"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_11"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_12"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_13"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_14"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_15"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_16"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_17"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_18"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_19"
			$BackupGroups += New-BackupGroup -Name "DC1_VMWARE_20"
		}
	"DC2VC"
		{
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_01"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_02"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_03"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_04"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_05"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_06"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_07"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_08"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_09"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_10"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_11"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_12"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_13"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_14"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_15"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_16"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_17"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_18"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_19"
			$BackupGroups += New-BackupGroup -Name "DC2_VMWARE_20"
		}
}

Write-INGLog -Message "Populating Datastores & Controllers" -Color "GREEN"
foreach ($BackupGroup in $BackupGroups) { $BackupGroup.PopulateDatastoresAndControlers($AllDatastores) }
Write-INGLog -Message "Setting backup groups" -Color "GREEN"

foreach ($VM in $AllVMs) {

	$VM_Annotation = $VM.CustomFields["BackupGroup"]
	$Count++
	
	if ($VM_Annotation -eq "NoBackup") {
		Write-INGLog -Message ("Virtual Machine {0} does not need to be backed up" -f $VM.Name) -Color "YELLOW"
		continue
	}
	
	if ($VM_Annotation -match "Special") {
		Write-INGLog -Message ("Virtual Machine {0} has a special group" -f $VM.Name) -Color "YELLOW"
		continue
	}
	
	$VM_Size           = BackupVMSize -PVM $VM
	$VM_Type           = GetVMType -PVM $VM
	$VM_Datastore      = Get-INGDatastoreFromVM -VMName $VM.Name
	$VM_Controler      = $VM_Datastore.Split(".")[3]
	$VM_Name           = $VM.Name
	$VM_Version        = $VM.ExtensionData.Config.Version
	$DatastoreSizeMin  = 1000000
	$ControlerSizeMin  = 1000000
	
	Write-INGLog -Message ("({0}) - Setting BackupGroup for {1}: " -f $Count, $VM_Name) -Color "CYAN" -NoReturn
	
	foreach ($BackupGroup in $BackupGroups) {
		$DatastoreSize = $BackupGroup.GetDatastoreSize($VM_Datastore)
		$ControlerSize = $BackupGroup.GetControlerSize($VM_Datastore)
		if ($DatastoreSizeMin -gt $DatastoreSize ) { $DatastoreSizeMin = $DatastoreSize }
		if ($ControlerSizeMin -gt $ControlerSize ) { $ControlerSizeMin = $ControlerSize }
	}
	
	$BackupGroup = $BackupGroups | Sort-Object CurrentControlerSize,CurrentDatastoreSize,Size,Name | Select-Object -First 1
	$BackupGroup.AddVM($VM_Name,$VM_Size,$VM_Datastore)
	if ($VM_Type -eq "Windows") { $Command = ("bpplclients {0} -add {1} {2} windows7Server64Guest;sleep 3;" -f $BackupGroup.Name,$VM_Name,$VM_Version) }
		else { $Command = ("bpplclients {0} -add {1} {2} rhel5_64Guest;sleep 3;" -f $BackupGroup.Name,$VM_Name,$VM_Version) }
	Write-INGLog -Message ("{0}" -f $BackupGroup.Name) -NoDateLog
	
	if (!$NoExcel)      { InsertTableRow $VM.Name $VM_Size $BackupGroup.Name $VM_Controler $VM_Datastore $BackupGroup.Size $Command }
	if (!$NoAnnotation) { $VM.ExtensionData.setCustomValue("BackupGroup",$BackupGroup.Name) }
}

UninitializeEnvironment


# BackupGruplarını aluştur, tüm gruplara tüm datastoreları ve controller'ları ekle
# Gruplara göre döngüye sok, o datastore'un tüm gruplarda kaç kere tekrar ettiğini bul, minimumunu al
# Grupları sort et, RepeatCount, Size, VMCount'a göre
# Gelen ilk gruba VM'i dahil et. Counter'ları artır. Sonraki VM'e geç.