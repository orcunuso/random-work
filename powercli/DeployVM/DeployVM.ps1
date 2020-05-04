# Prepared by : Ozan Orçunus
# Script Name : DeployVM.ps1
# Version     : 1.00
# Create Date : 30.01.2013
# Modify Date : 09.04.2013

# [FUNCTIONS - General] =================================================================

param ( [Parameter(Mandatory=$true)]
		[string]$Instance )

function CheckPowerCLI {
	param ([String]$PSPath)
	$VMSnapin = (Get-PSSnapin | Where {$_.Name -eq "VMware.VimAutomation.Core"}).Name
	if ($VMSnapin -ne "VMware.VimAutomation.Core") {
		CD "C:\Program Files\VMware\Infrastructure\vSphere PowerCLI\Scripts\"
		Add-PSSnapin VMware.VimAutomation.Core
		.\Initialize-PowerCLIEnvironment.ps1
		CD $PSPath
	}
}

function InitializeEnvironment {
	$Global:ScrPath   = "C:\Scripts\DeployVM\"
	$Global:LogFile   = $Global:ScrPath + "Logs\DeployVM.log"
	$Global:XlsFile   = $Global:ScrPath + "Config\DeployVM.xlsx"
	$Global:CtrlFile  = $Global:ScrPath + "Config\DeployVM.cnt"
	$Global:Index     = 0
	
	$Global:OSType    = $null
	$Global:Template  = $null
	$Global:OSCustom  = $null
	$Global:VMSize    = 0
	$Global:VMCount   = 22
	
	$Global:Culture   = New-Object System.Globalization.CultureInfo("en-US")
	$ScriptUser       = ([Environment]::UserName).ToUpper($Global:Culture)
	$ScriptHost       = ([Environment]::MachineName).ToUpper($Global:Culture)
	
	CheckPowerCLI $Global:ScrPath
	
	WriteLog (" ")
	WriteLog ("********** Script started **********")
	
	$CouldOpen = $False
	Do {
		Try {
			Switch ($ScriptUser) {
				"ORCUNUSO" { $Global:CredStore = Get-VICredentialStoreItem -File "C:\Scripts\CredStore\OZAN-Store.xml"   }
				Default    { $Global:CredStore = Get-VICredentialStoreItem -File "C:\Scripts\CredStore\ORCH-Store.xml"   }
			}
			$CouldOpen = $True
		}
		Catch {
			Start-Sleep -s 1
			WriteLog ("Waiting for another process for CredStore") "WARNING"
		}
	} Until ($CouldOpen)
	
	$Global:CredNetApp     = CreateCredential -CredStore $Global:CredStore -CredName "NETAPP"
	$Global:CredVCenter    = CreateCredential -CredStore $Global:CredStore -CredName "VCENTER"
	$Global:CredEsx        = CreateCredential -CredStore $Global:CredStore -CredName "ESX"
	$Global:CredDefault    = CreateCredential -CredStore $Global:CredStore -CredName "WINDEF"
	$Global:CredAttribute  = CreateCredential -CredStore $Global:CredStore -CredName "SVCATTRIBUTE"

	WriteLog ("Initializing environment completed")
}

function CreateCredential {
	param ($CredStore, [String]$CredName)
	$CredPass  = ConvertTo-SecureString ($CredStore | Where {$_.Host -eq $CredName}).Password -AsPlainText -Force
	$CredUser  = ($CredStore | Where {$_.Host -eq $CredName}).User
	$Cred      = New-Object System.Management.Automation.PSCredential ($CredUser, $CredPass)
	$Cred
}

function GetSecurePass {
    param ($SecurePassword)
    $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($SecurePassword)
    $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)
    $Password
}

function WriteLog {
	param ([String]$Message, [string]$Severity)
	$LogMessage = (Get-Date).ToString() + " | " + $Message
	$LogMessage >> $Global:LogFile
	switch ($Severity) {
		"ERROR"		{ Write-Host $LogMessage -ForegroundColor Red }
		"WARNING"	{ Write-Host $LogMessage -ForegroundColor Yellow }
		"INFO"		{ Write-Host $LogMessage -ForegroundColor Cyan }
		default		{ Write-Host $LogMessage }
	}
}

function ConnectVCenter {
	param ([String]$vCenter)
	switch ($vCenter) {
		"DC1VC" { $vCenterFQDN = "dc1vc01.mydomain.local" }
		"PREVC" { $vCenterFQDN = "dc1vc03.mydomain.local" }
		"DC2VC" { $vCenterFQDN = "dc2vc01.mydomain.local" }
		"DC3VC" { $vCenterFQDN = "dc3vc01.mydomain.local" }
	}
	Connect-VIServer -Server $vCenterFQDN -Credential $Global:CredVCenter > $Null
	WriteLog ("Connected to " + $vCenter)
}

function ConnectNetapp {
	param ([String]$Controller)
	Connect-NaController -Name $Controller -Credential $Global:CredNetApp -HTTPS > $Null
	WriteLog ("Connected to " + $Controller)
}

function DisconnectVCenter {
	param ([String]$vCenter)
	Disconnect-VIServer -Confirm:$false > $Null
	WriteLog ("Disconnected from " + $vCenter)
}

function UpdateTableRow {
	param ([String]$UpdateField, [String]$UpdateValue, [String]$VirtualMachineName)
	$ExcelSheet   = "DeployVM"
	$OleDbConn    = New-Object "System.Data.OleDb.OleDbConnection"
	$OleDbCmd     = New-Object "System.Data.OleDb.OleDbCommand"
	$OleDbConn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$Global:XlsFile;Extended Properties=""Excel 12.0 Xml;HDR=YES"";"
	$OleDbConn.Open()
	$OleDbCmd.Connection = $OleDbConn
	$OleDbCmd.CommandText = ("Update [{0}$] Set {1}='{2}' Where Name='{3}'" -f $ExcelSheet,$UpdateField,$UpdateValue,$VirtualMachineName)
	$OleDbCmd.ExecuteNonQuery() | Out-Null
	$OleDbConn.Close()
}

function CreateComputerAccount {
	param ([String]$Site, [String]$Domain, [String]$ComputerName)
	
	if ($Domain -eq "mydomain.local") {
		switch ($Site) {
			"DC1" { $DomainController = "DC1.mydomain.local"   }
		}
		
		$DomainUser = ("MYDOMAIN\{0}" -f $Global:CredAttribute.UserName)
		$DomainPass = $Global:CredAttribute.Password
		
		# Search for computer accounts in AD
		
		$ConnectionString = ("LDAP://{0}/OU=Servers,DC=mydomain,DC=local" -f $DomainController)
		$objDomainSrch = New-Object System.DirectoryServices.DirectoryEntry($ConnectionString, $DomainUser, (GetSecurePass $DomainPass))
		$objSearcher   = New-Object System.DirectoryServices.DirectorySearcher
		$objSearcher.SearchRoot  = $objDomainSrch
		$objSearcher.PageSize    = 100
		$objSearcher.Filter      = ("(&(objectCategory=Computer)(name={0}))" -f $ComputerName)
		$objSearcher.SearchScope = "Subtree"
		$colProperties = "name"
		foreach ($i in $colProperties) { $objSearcher.PropertiesToLoad.Add($i) | Out-Null }
		$SearchResult = $objSearcher.FindOne()
		
		# Delete computer account if search result is positive
		
		if ($SearchResult) {
			WriteLog ("Computer account exists, deleting")
			try { 
				$SearchResult.getDirectoryEntry().DeleteObject(0) }
			catch {
				WriteLog ("Deleting computer account failed: {0}" -f $ComputerName) "ERROR"
				$ErrorMessage = $_.Exception.Message
				WriteLog ("{0}" -f $ErrorMessage)
			}
		} else {
			WriteLog ("Computer account does not exist, creating")
		}
		
		$objSearcher.Dispose()
		$objDomainSrch.Close()
		$objDomainSrch.Dispose()
		
		# Create new computer account
		
		try {
			$ConnectionString = ("LDAP://{0}/OU=DeploymentServers,DC=mydomain,DC=local" -f $DomainController)
			$objDomain   = New-Object System.DirectoryServices.DirectoryEntry($ConnectionString, $DomainUser, (GetSecurePass $DomainPass))
			$objComputer = $objDomain.Create("computer", "CN=" + $ComputerName)
			$objComputer.Put("sAMAccountName",$ComputerName + "$")
			$objComputer.Put("userAccountControl", 4128)
			$objComputer.SetInfo() 
			WriteLog ("Computer account created: {0}" -f $ComputerName) }
		catch {
			WriteLog ("Creating computer account failed: {0}" -f $ComputerName) "ERROR"
			$ErrorMessage = $_.Exception.Message
			WriteLog ("{0}" -f $ErrorMessage) }
		finally {
			$objDomain.Close()
			$objDomain.Dispose()
		}
	}
}

function DoesVMExist {
	param ([String]$VMName)
	$VM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
	if ($VM -eq $null) { return $false }
		else { return $true }
}

function ChooseDatastore {
	param ([System.Data.DataRow]$TableRow)
	
	$Datastores = Get-Datastore | Where-Object { $_.Name -match $TableRow.DataStore }
	$Datastores = $Datastores | Get-Random -Count $Datastores.Count -ErrorAction:SilentlyContinue
	foreach ($DS in $Datastores) {
		$AcceptCapacity = [int]$DS.CapacityMB / 1024 * 0.1
		$RemainCapacity = [int]($DS.FreeSpaceMB / 1024) - $Global:VMSize
		$DSVMCount        = $DS.ExtensionData.Vm.Count + 1
		if (($RemainCapacity -gt $AcceptCapacity) -and ($DSVMCount -lt $Global:VMCount)) {
			WriteLog ("Choosen Datastore : {0}" -f $DS.Name)
			WriteLog ("Remaining Capacity: {0}" -f $RemainCapacity)
			WriteLog ("Datastore VM Count: {0}" -f $DSVMCount)
			return $DS.Name
		}
	}
	
	WriteLog ("No Available Datastore Found in {0}" -f $TableRow.DataStore) "ERROR"
	return "NoDatastore"
}

function ChooseDatastoreFromFolderName {
	param ([System.Data.DataRow]$TableRow)
	
	$Datastores     = @()
	$Folder         = Get-Folder -Name $TableRow.DataStore
	$FolderView     = Get-View -Id $Folder.Id
	$DatastoreItems = $FolderView.ChildEntity | Where-Object { $_.Type -eq "Datastore" }
	foreach ($DatastoreItem in $DatastoreItems) {
		$Datastores += Get-Datastore -Id ("Datastore-{0}" -f $DatastoreItem.Value)
	}
	
	$Datastores = $Datastores | Get-Random -Count $Datastores.Count -ErrorAction:SilentlyContinue
	foreach ($DS in $Datastores) {
		$AcceptCapacity = [int]$DS.CapacityMB / 1024 * 0.1
		$RemainCapacity = [int]($DS.FreeSpaceMB / 1024) - $Global:VMSize
		$DSVMCount        = $DS.ExtensionData.Vm.Count + 1
		if (($RemainCapacity -gt $AcceptCapacity) -and ($DSVMCount -lt $Global:VMCount)) {
			WriteLog ("Choosen Datastore : {0}" -f $DS.Name)
			WriteLog ("Remaining Capacity: {0}" -f $RemainCapacity)
			WriteLog ("Datastore VM Count: {0}" -f $DSVMCount)
			return $DS.Name
		}
	}
	
	WriteLog ("No Available Datastore Found in {0}" -f $TableRow.DataStore) "ERROR"
	return "NoDatastore"
}

function ChooseFolder {
	param ([System.Data.DataRow]$TableRow)

	$FolderName = $TableRow.Site + ".Deploy"
	
	if ($Global:OSType -eq "Windows") {
		switch ($TableRow.Department) {
			"Ag Yonetimi"					{ $FolderName = $TableRow.Site + ".Windows.AgYonetimi"         }
			"Cagri Merkezi Teknolojileri"	{ $FolderName = $TableRow.Site + ".Windows.CallCenter"         }
			"Guvenlik"						{ $FolderName = $TableRow.Site + ".Windows.Guvenlik"           }
			"Servis Yonetimi"				{ $FolderName = $TableRow.Site + ".Windows.ServisYonetimi"     }
			"Sistem Mimari"					{ $FolderName = $TableRow.Site + ".Windows.SistemMimari"       }
			"Sunucu Sistemleri"				{ $FolderName = $TableRow.Site + ".Windows.SunucuSistemleri"   }
			"Mesajlasma Sistemleri"			{ $FolderName = $TableRow.Site + ".Windows.SunucuSistemleri"   }
			"Sunucu Yonetimi"				{ $FolderName = $TableRow.Site + ".Windows.SunucuSistemleri"   }
			"Unix Yonetimi"					{ $FolderName = $TableRow.Site + ".Windows.Unix"               }
			"Veritabani Yonetimi"			{ $FolderName = $TableRow.Site + ".Windows.VeritabaniYonetimi" }
			"Yedekleme ve Depolama"         { $FolderName = $TableRow.Site + ".Windows.YedeklemeDepolama"  }
			default							{ $FolderName = $TableRow.Site + ".Windows.Others"             }
		}
	}
	
	if ($Global:OSType -eq "Linux")   {
		switch ($TableRow.Department) {
			"Ag Yonetimi"					{ $FolderName = $TableRow.Site + ".Linux.AgYonetimi"           }
			"Cagri Merkezi Teknolojileri"	{ $FolderName = $TableRow.Site + ".Linux.CallCenter"           }
			"Guvenlik"						{ $FolderName = $TableRow.Site + ".Linux.Guvenlik"             }
			"Servis Yonetimi"				{ $FolderName = $TableRow.Site + ".Linux.ServisYonetimi"       }
			"Sistem Mimari"					{ $FolderName = $TableRow.Site + ".Linux.SistemMimari"         }
			"Sunucu Sistemleri"				{ $FolderName = $TableRow.Site + ".Linux.SunucuSistemleri"     }
			"Mesajlasma Sistemleri"			{ $FolderName = $TableRow.Site + ".Linux.SunucuSistemleri"     }
			"Sunucu Yonetimi"				{ $FolderName = $TableRow.Site + ".Linux.SunucuSistemleri"     }
			"Unix Yonetimi"					{ $FolderName = $TableRow.Site + ".Linux.Unix"                 }
			"Veritabani Yonetimi"			{ $FolderName = $TableRow.Site + ".Linux.VeritabaniYonetimi"   }
			"Yedekleme ve Depolama"         { $FolderName = $TableRow.Site + ".Linux.YedeklemeDepolama"    }
			default							{ $FolderName = $TableRow.Site + ".Linux.Others"               }
		}
	}
	
	WriteLog ("Choosen Folder    : {0}" -f $FolderName)
	return $FolderName
}
	
function CreateCustomization {
	param ([System.Data.DataRow]$TableRow)
	
	$ExistingCustomization = Get-OSCustomizationSpec -Name ("OSCustomization_{0}" -f $TableRow.Name) -ErrorAction SilentlyContinue
	if ($ExistingCustomization) {
		Remove-OSCustomizationSpec -OSCustomizationSpec $ExistingCustomization -Confirm:$false
		WriteLog ("Existing OSCustomization found, deleting")
	}
	
	$Global:Template   = $null
	$Global:OSType     = $null
	$Global:OSCustom   = $null
	$Global:TempPath   = $null
	
	switch ($TableRow.OS) {
			
			default { 
				$Custom_Template   = "Temp_Win2008SSx64R2"
				$Custom_OsType     = "Windows"
				$Custom_WinType    = "Windows2008"
				$Custom_ProKeyPart = "-ProductKey AAAAA-BBBBB-CCCCC-DDDDD-EEEEE"
				$Global:VMSize     = 30 }
		}

		if ($Custom_OsType -eq "Windows") {
			$Custom_Name           = ("OSCustomization_{0}" -f $TableRow.Name)
			$Custom_Type           = ("Persistent")
			$Custom_FullName       = ('"Tech"')
			$Custom_OrgName        = ('"Org"')
			$Custom_AdminPassword  = GetSecurePass $Global:CredDefault.Password
			$Custom_TimeZone       = ('"E. Europe"')
			$Custom_Domain         = $TableRow.Domain
				if ($Custom_WinType -eq "Windows2003")  { $Custom_DomainUser = ("{0}" -f $Global:CredAttribute.UserName) }
				if ($Custom_WinType -eq "Windows2008")  { $Custom_DomainUser = ("{0}@{1}" -f $Global:CredAttribute.UserName, $Custom_Domain) }
				if ($Custom_WinType -eq "Windows2012")  { $Custom_DomainUser = ("{0}@{1}" -f $Global:CredAttribute.UserName, $Custom_Domain) }
			$Custom_DomainPassword = GetSecurePass $Global:CredAttribute.Password
			$Custom_NamingScheme   = ("Vm")
			$Custom_LicenseMode    = ("PerSeat")
			$Custom_IPAddress      = $TableRow.IPAddress
			$Custom_SubnetMask     = $TableRow.SubnetMask
			$Custom_Gateway        = $TableRow.Gateway
				if ($TableRow.vCenter -eq "PREVC") { $Custom_DNSServers = ("10.10.10.1","10.10.10.10.2") }
			$Custom_StaticPart1    = ("-Name {0} -Type {1} -FullName {2} -OrgName {3} -OSType {4} -ChangeSid -AdminPassword {5} -TimeZone {6} -AutoLogonCount 1" -f `
									  $Custom_Name,$Custom_Type,$Custom_FullName,$Custom_OrgName,$Custom_OsType,$Custom_AdminPassword,$Custom_TimeZone)

			switch ($TableRow.InstallType) {
				"FreshInstall" {
					$Custom_RunOncePart    =  (" -GuiRunOnce ")
					$Custom_RunOncePart    += ("`'cmd /C echo GuiRunOnce Commands Executed > C:\VMdeploy_Customization.txt`',")
					$Custom_RunOncePart    += ("`'C:\Windows\System32\reg.exe add HKLM\SYSTEM\NewServerTSQ /v ApplyNewServerTSQ /t REG_SZ /d YES /f`',")
					$Custom_RunOncePart    += ("`'C:\Windows\System32\reg.exe add HKLM\SYSTEM\NewServerTSQ /v InstallTripwire /t REG_SZ /d {0} /f`'," -f $TableRow.InstallTripwire)
					$Custom_RunOncePart    += ("`'C:\Windows\System32\reg.exe add HKLM\SYSTEM\NewServerTSQ /v InstallSSIM /t REG_SZ /d {0} /f`'," -f $TableRow.InstallSSIM)
					$Custom_RunOncePart    += ("`'C:\Windows\System32\reg.exe add HKLM\SYSTEM\NewServerTSQ /v Department /t REG_SZ /d `"{0}`" /f`'," -f $TableRow.Department)
					$Custom_RunOncePart    += ("`'C:\Windows\System32\reg.exe add HKLM\SYSTEM\NewServerTSQ /v NetworkInterface /t REG_SZ /d {0} /f`'," -f $TableRow.PortGroup.Replace("dvp.",""))
					$Custom_RunOncePart    += ("`'shutdown /r /t 30`'") }
				"CloneCopy" {
					$Custom_RunOncePart    =  (" -GuiRunOnce ")
					$Custom_RunOncePart    += ("`'cmd /C echo GuiRunOnce Commands Executed > C:\VMdeploy_Customization.txt`',")
					$Custom_RunOncePart    += ("`'C:\Windows\System32\reg.exe add HKLM\SYSTEM\NewServerTSQ /v ApplyNewServerTSQ /t REG_SZ /d NO /f`',")
					$Custom_RunOncePart    += ("`'C:\Windows\System32\reg.exe add HKLM\SYSTEM\NewServerTSQ /v InstallTripwire /t REG_SZ /d {0} /f`'," -f $TableRow.InstallTripwire)
					$Custom_RunOncePart    += ("`'C:\Windows\System32\reg.exe add HKLM\SYSTEM\NewServerTSQ /v InstallSSIM /t REG_SZ /d {0} /f`'," -f $TableRow.InstallSSIM)
					$Custom_RunOncePart    += ("`'C:\Windows\System32\reg.exe add HKLM\SYSTEM\NewServerTSQ /v NetworkInterface /t REG_SZ /d {0} /f`'," -f $TableRow.PortGroup.Replace("dvp.",""))
					$Custom_RunOncePart    += ("`'WMIC /namespace:\\root\ccm path sms_client CALL TriggerSchedule `"{00000000-0000-0000-0000-000000000001}`" /NOINTERACTIVE`'") }
			}
			
			if ($TableRow.Domain -ne "WORKGROUP") {
				$Custom_DomainPart = (" -Domain {0} -DomainUser {1} -DomainPassword {2}" -f $Custom_Domain,$Custom_DomainUser,$Custom_DomainPassword) 
			} else {
				$Custom_DomainPart = (" -Workgroup {0}" -f $Custom_Domain)
			}
			
			$Custom_StaticPart2    = (" -NamingScheme {0} -LicenseMode {1}" -f $Custom_NamingScheme,$Custom_LicenseMode)
			$Custom_FULLCOMMAND    = ("New-OSCustomizationSpec {0}{1}{2} {3}{4}" -f $Custom_StaticPart1,$Custom_RunOncePart,$Custom_DomainPart,$Custom_ProKeyPart,$Custom_StaticPart2)
			
			try {
				$OSCustomization = Invoke-Expression -Command $Custom_FULLCOMMAND
				$OSCustomizationNIC = Get-OSCustomizationNicMapping -OSCustomizationSpec $OSCustomization
				Remove-OSCustomizationNicMapping -OSCustomizationNicMapping $OSCustomizationNIC -Confirm:$false
				$OSCustomizationNIC = New-OSCustomizationNicMapping -OSCustomizationSpec $OSCustomization -IpMode UseStaticIP -IpAddress $Custom_IPAddress -SubnetMask $Custom_SubnetMask -DefaultGateway $Custom_Gateway -Dns $Custom_DNSServers
				WriteLog ("{0} succesfully created" -f $OSCustomization.Name)
			} catch {
				WriteLog ("Failed to create OSCustomization") "ERROR"
				$ErrorMessage = $_.Exception.Message
				WriteLog ("{0}" -f $ErrorMessage)
			}
		}
		
		$Global:Template = $Custom_Template
		$Global:OSType   = $Custom_OsType
		$Global:OSCustom = $OSCustomization
}

function AddTemplateToInventory {
	param ([System.Data.DataRow]$TableRow)
	
	do {
		$Template = $null
		$VM       = $null
		$Template = Get-Template -Name $Global:Template -ErrorAction:SilentlyContinue
		$VM       = Get-VM -Name $Global:Template -ErrorAction:SilentlyContinue
		if ($Template -or $VM) {
			WriteLog ("{0} is busy, script will suspend for 5 minutes" -f $Global:Template) "WARNING"
			Start-Sleep -Seconds 300
		}
	} while ($Template -or $VM)
	
	$TemplateHost        = Get-Cluster -Name $TableRow.Cluster | Get-VMHost | Where-Object {$_.ConnectionState -eq "Connected"} | Select-Object -First 1
	$TemplatePath        = "[COMMON.Templates] " + $Global:TempPath
	$TemplateFolder      = ("{0}.Templates" -f $TableRow.Site)
	$TemplateDestination = Get-View -ViewType Folder -Property Name -Filter @{"Name" = $TemplateFolder}
	
	try {
		WriteLog ("Adding template (" + $Global:Template + ") to inventory via (" + $TemplateHost + ")")
		$TemplateDestination.RegisterVM_Task($TemplatePath, $Global:Template, $True, $Null, (Get-View -ViewType HostSystem -Property Name -Filter @{"Name" = $TemplateHost.Name}).MoRef) > $Null
		Start-Sleep -seconds 10
		return $true
	} catch {
		$ErrorMessage = $_.Exception.Message
		WriteLog("{0}" -f $ErrorMessage) "ERROR"
		return $false
	}
}

function RemoveTemplateFromInventory {
	$Template = Get-Template -Name $Global:Template -ErrorAction:SilentlyContinue
	if ($Template) {
		WriteLog ("Removing template (" + $Global:Template + ")")
		Remove-Template -Template $Template -Confirm:$false
	} else {
		WriteLog ("Template to remove not found (" + $Global:Template + ")") "WARNING"
	}
}

function DeployVM {
	param ([System.Data.DataRow]$TableRow)

	$ResourcePool = ("{0}.Generic" -f $TableRow.Cluster)
	$Folder       = ChooseFolder $TableRow
	$TemplateOK   = AddTemplateToInventory $TableRow
	if (!$TemplateOK) { 
		WriteLog ("Error with registering template") "WARNING"
		return
	}
	
	if ($Global:OSType -eq "Windows") {
		WriteLog ("VM creation command started")
		if ($TableRow.InstallType -eq "FreshInstall") {
			$Global:VMSize += [int]$TableRow.Disk1
			$Global:VMSize += [int]$TableRow.Disk2
			$Global:VMSize += [int]$TableRow.Disk3
			$Datastore      = ChooseDatastoreFromFolderName $TableRow
			if ($Datastore -ne "NoDatastore") {
				$VM = New-VM -Name $TableRow.Name -Template $Global:Template -DiskStorageFormat Thick -OSCustomizationSpec $Global:OSCustom -ResourcePool $ResourcePool -Location $Folder -Datastore $Datastore -Confirm:$false
			}
		} elseif ($TableRow.InstallType -eq "CloneCopy") {
			$VM = Get-VM -Name $TableRow.SourceVM -ErrorAction SilentlyContinue
			if ($VM) {
				$Global:VMSize = [int]$VM.UsedSpaceGB
				$Datastore = ChooseDatastoreFromFolderName $TableRow
				if ($Datastore -ne "NoDatastore") {
					$VM = New-VM -Name $TableRow.Name -VM $TableRow.SourceVM -DiskStorageFormat Thick -OSCustomizationSpec $Global:OSCustom -ResourcePool $ResourcePool -Location $Folder -Datastore $Datastore -Confirm:$false
				}
			} else {
				WriteLog ("SourceVM {0} not found" -f $TableRow.SourceVM)
				$VM = $null
			}
		}
	}
	
	if ($Global:OsType -eq "Linux") {
		WriteLog ("VM creation command started")
		if ($TableRow.InstallType -eq "FreshInstall") {
			$Global:VMSize += [int]$TableRow.Disk1
			$Global:VMSize += [int]$TableRow.Disk2
			$Global:VMSize += [int]$TableRow.Disk3
			$Datastore = ChooseDatastoreFromFolderName $TableRow
			if ($Datastore -ne "NoDatastore") { 
				$VM = New-VM -Name $TableRow.Name -Template $Global:Template -DiskStorageFormat Thick -ResourcePool $ResourcePool -Location $Folder -Datastore $Datastore -Confirm:$false
			}
		} elseif ($TableRow.InstallType -eq "CloneCopy") {
			$VM = Get-VM -Name $TableRow.SourceVM -ErrorAction SilentlyContinue
			if ($VM) {
				$Global:VMSize = [int]$VM.UsedSpaceGB
				$Datastore = ChooseDatastoreFromFolderName $TableRow
				if ($Datastore -ne "NoDatastore") {
					$VM = New-VM -Name $TableRow.Name -VM $TableRow.SourceVM -DiskStorageFormat Thick -ResourcePool $ResourcePool -Location $Folder -Datastore $Datastore -Confirm:$false
				}
			} else {
				WriteLog ("SourceVM {0} not found" -f $TableRow.SourceVM)
				$VM = $null
			}
		}	
	}
	
	RemoveTemplateFromInventory
	Start-Sleep -Seconds 5
	$VM = Get-VM -Name $TableRow.Name -ErrorAction SilentlyContinue
	
	if ($VM) {
		WriteLog ("VM creation confirmed: {0}" -f $VM.Name)
		
		if ($TableRow.InstallType -eq "FreshInstall") {
			WriteLog ("Adding hard disks if required")
			switch ([int]$TableRow.NoofDisks) {
				1 {	$DiskSizeKB = [int]$TableRow.Disk1 * 1024 * 1024
					$HD = New-HardDisk -VM $VM -CapacityKB $DiskSizeKB -Confirm:$false }
				2 { $DiskSizeKB = [int]$TableRow.Disk1 * 1024 * 1024
					$HD = New-HardDisk -VM $VM -CapacityKB $DiskSizeKB -Confirm:$false
					$DiskSizeKB = [int]$TableRow.Disk2 * 1024 * 1024
					$HD = New-HardDisk -VM $VM -CapacityKB $DiskSizeKB -Confirm:$false }
				3 { $DiskSizeKB = [int]$TableRow.Disk1 * 1024 * 1024
					$HD = New-HardDisk -VM $VM -CapacityKB $DiskSizeKB -Confirm:$false
					$DiskSizeKB = [int]$TableRow.Disk2 * 1024 * 1024
					$HD = New-HardDisk -VM $VM -CapacityKB $DiskSizeKB -Confirm:$false
					$DiskSizeKB = [int]$TableRow.Disk3 * 1024 * 1024
					$HD = New-HardDisk -VM $VM -CapacityKB $DiskSizeKB -Confirm:$false }
				default { WriteLog ("No system disk requested") }
			}
		}
		
		WriteLog ("Setting network adapter properties")
		$NIC = Get-NetworkAdapter -VM $VM
		
		$PGLoop = $true
		$PGName = $null
		WriteLog ("Checking port group existance. Loops if false")
		while ($PGLoop) {
			$PGName = Get-VDPortgroup -Name $TableRow.PortGroup -ErrorAction SilentlyContinue
			if ($PGName) { $PGLoop = $false }
				else { Start-Sleep -Seconds 90 }
		}
		
		Set-NetworkAdapter -NetworkAdapter $NIC -StartConnected:$true -WakeOnLan:$true -Confirm:$false | Out-Null
		Set-NetworkAdapter -NetworkAdapter $NIC -Portgroup $TableRow.PortGroup -Confirm:$false | Out-Null

		WriteLog ("Setting CPU, Memory and annotations")
		$int64MEM = [int64]$TableRow.MEM
		$int32CPU = [int32]$TableRow.CPU
		
		if (($int64MEM -ne 0) -and ($int32CPU -ne 0)) {
			Set-VM -VM $VM -MemoryMB $int64MEM -NumCPU $int32CPU -Notes "" -Confirm:$false | Out-Null
		}
		Set-Annotation -Entity $VM -CustomAttribute "Application" -Value $TableRow.Application -Confirm:$false | Out-Null
		Set-Annotation -Entity $VM -CustomAttribute "Description" -Value $TableRow.Description -Confirm:$false | Out-Null
		Set-Annotation -Entity $VM -CustomAttribute "Environment" -Value $TableRow.Environment -Confirm:$false | Out-Null
		Set-Annotation -Entity $VM -CustomAttribute "Department" -Value $TableRow.Department -Confirm:$false | Out-Null
		Set-Annotation -Entity $VM -CustomAttribute "Responsible" -Value $TableRow.Responsible -Confirm:$false | Out-Null
		Set-Annotation -Entity $VM -CustomAttribute "Dead Line" -Value $TableRow.DeadLine -Confirm:$false | Out-Null
		
		$strVersion = $VM.ExtensionData.Config.Version
		if ($strVersion -eq "vmx-08") {
			WriteLog ("Hardware Version is {0}, no action required" -f $strVersion)
		}	else {
			WriteLog ("Hardware Version is {0}, upgrading to vmx-08" -f $strVersion)
			$VM.ExtensionData.UpgradeVM("vmx-08")
		}
		
		WriteLog ("Starting VM")
		Start-VM -VM $VM -Confirm:$false | Out-Null
		UpdateTableRow "Status" "VMDEPLOYED" $TableRow.Name
		UpdateTableRow "CreateDate" (Get-Date).ToString("yyyyMMddhhmm") $TableRow.Name
	} else {
		WriteLog ("VM Deployment Failed, VM not found") "ERROR"
		UpdateTableRow "Status" "ERROR" $TableRow.Name
	}
}

# ============================================================================================
# ===================================  [MAIN]  ===============================================
# ============================================================================================

InitializeEnvironment

$ExcelSheet   = "DeployVM"
$OleDbConn    = New-Object "System.Data.OleDb.OleDbConnection"
$OleDbCmd     = New-Object "System.Data.OleDb.OleDbCommand"
$OleDbAdapter = New-Object "System.Data.OleDb.OleDbDataAdapter"
$Table        = New-Object "System.Data.DataTable"

$OleDbConn.ConnectionString = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$Global:XlsFile;Extended Properties=""Excel 12.0 Xml;HDR=YES"";"
$OleDbConn.Open()
$OleDbCmd.Connection = $OleDbConn
$OleDbCmd.CommandText = ("Select * from [{0}$] Where Status='NotStarted' And Instance='{1}'" -f $ExcelSheet, $Instance)
$OleDbAdapter.SelectCommand = $OleDbCmd
$RowsReturned = $OleDbAdapter.Fill($Table)
$OleDbConn.Close()

while ($Global:Index -lt $RowsReturned) {
	if ((Get-Content -Path $Global:CtrlFile) -eq "STOP") { 
		WriteLog ("Script terminated by user input!!!") "WARNING"
		break 
	}
	
	$TableRow = $Table.Rows[$Global:Index]
	
	if ($TableRow.InstallType -eq "FreshInstall") {
		WriteLog ("Deploying Virtual Machine - Fresh Install - {0}" -f $TableRow.Name) "INFO"
		ConnectVCenter -vCenter $TableRow.vCenter
		
		if (DoesVMExist $TableRow.Name -eq $false) {
			WriteLog ("Duplicate VM exists, skipping") "ERROR"
			DisconnectVCenter -vCenter $TableRow.vCenter
			$Global:Index++; continue
		}
		
		CreateCustomization $TableRow
		DeployVM $TableRow
		DisconnectVCenter -vCenter $TableRow.vCenter
	} 
	
	if ($TableRow.InstallType -eq "CloneCopy") {
		WriteLog ("Deploying Virtual Machine - Clone Copy - {0}" -f $TableRow.Name) "INFO"
		ConnectVCenter -vCenter $TableRow.vCenter
		
		if (DoesVMExist $TableRow.Name -eq $false) {
			WriteLog ("Duplicate VM exists, skipping") "ERROR"
			DisconnectVCenter -vCenter $TableRow.vCenter
			$Global:Index++; continue
		}
		
		CreateCustomization $TableRow
		DeployVM $TableRow
		DisconnectVCenter -vCenter $TableRow.vCenter
	}
	
	$Global:Index++
	Start-Sleep -Seconds 5
}

WriteLog ("********** Script completed **********")

# [ENDED] =====================================================================================
