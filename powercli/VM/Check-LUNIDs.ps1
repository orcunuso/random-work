# *********************************************************************
#
# Powershell script that checks LUNIDs of ESX hosts across clusters
#
# USAGE: ./VM-Prod-CheckLUNIDs.ps1
#
# ASSUMPTIONS:
# Console already connected to vCenter
# Storage Vendor as NetApp
#
# *********************************************************************

$EXCEL = New-Object -ComObject Excel.Application
$Workbook = $EXCEL.Workbooks.Add()
$SheetCount = $Workbook.WorkSheets.Count

$Clusters = Get-Cluster | Sort-Object Name

if ($SheetCount -lt $Clusters.Count) {
	$Difference = $Clusters.Count - $SheetCount
	for ($i=0; $i -lt $Difference; $i++) { 
		$X = $Workbook.WorkSheets.Add()
	}
}

$ClusterCount = 1
foreach ($Cluster in $Clusters) {
	Write-Host Working on cluster: $Cluster.Name
	
	$WorkSheet = $Workbook.Worksheets.Item($ClusterCount)
	$Worksheet.Name = $Cluster.Name
	$Worksheet.Tab.Color = 2
	$Cells = $Worksheet.Cells
	$Cells.Item(1,1) = "DEVICE IDENTIFIERS"
	$LUNCount = 0
	$VMHostCount = 1
	
	$VMHosts = $Cluster | Get-VMHost | Where-Object { $_.ConnectionState -eq "Connected" } | Sort-Object Name
	foreach ($VMHost in $VMHosts) {
		$xlR = 1
		$xlC = $VMHostCount + 1
		$Cells.Item($xlR,$xlC) = $VMHost.Name.Split(".")[0]
		$LUNs = $VMHost | Get-SCSILun -LunType disk | Where-Object { $_.Vendor -eq "NETAPP" }
		
		foreach ($LUN in $LUNs) {
			$RangeFoundLUN = $Worksheet.UsedRange.Find($LUN.CanonicalName)
			if ($RangeFoundLUN) {
				$xlR = $RangeFoundLUN.Row
				$xlC = $VMHostCount + 1
				$Cells.Item($xlR,$xlC) = $LUN.RuntimeName.Split("L")[1]
			}
			else {
				$xlR = $LUNCount + 2
				$xlC = 1
				$Cells.Item($xlR,$xlC) = $LUN.CanonicalName
				$xlC = $VMHostCount + 1
				$Cells.Item($xlR,$xlC) = $LUN.RuntimeName.Split("L")[1]
				$LUNCount++
			}
		}
		$VMHostCount++
	}
	$Worksheet.UsedRange.Columns.AutoFit() | Out-Null
	$Worksheet.UsedRange.Borders.Weight = 2       # xlThin
	$Worksheet.UsedRange.Borders.LineStyle = 1    # xlContinuous
	$Worksheet.UsedRange.Borders.ColorIndex = 1   # xlColorIndexBlack
	$X = $Worksheet.ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $Worksheet.UsedRange, $null ,[Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes,$null)
	
	# Buraya kadar tabloyu oluþturduk. Þimdi kontrol ediyoruz.
	
	$ArrayID = New-Object System.Collections.ArrayList
	
	for ($R=2; $R -le $Worksheet.UsedRange.Rows.Count; $R++) {
		$ArrayID.Clear()
		for ($C=2; $C -le $Worksheet.UsedRange.Columns.Count; $C++) {
			if (!$ArrayID.Contains($Cells.Item($R,$C).Value2)) { $ArrayID.Add($Cells.Item($R,$C).Value2) | Out-Null }
		}
		
		$ArrayID
		
		if ($ArrayID.Count -ne 1) {
			$Cells.Item($R,1).Font.Bold = $True
			$Cells.Item($R,1).Interior.ColorIndex = 6	
		}
	}	
	
	$ClusterCount++
}

$FilePath = "C:\" + $global:DefaultVIServers + "-LUNID.xlsx"
$Workbook.SaveAs($FilePath)
$Workbook.Close()
$EXCEL.Quit()