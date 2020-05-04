# ********************************************************************************
#
# Powershell script that gets average CPU and memory utilization of previous month
#
# USAGE: ./Get-MonthlyCPU.ps1
#
# ASSUMPTIONS:
# PowerCLI already connected to vCenter
# 
# ********************************************************************************

#################### Constants & Variables #####################

$xlContinuous = 1
$xlThin = 2
$xlColorIndexBlack = 1

$VMHosts = Get-Cluster "TEST" | Get-VMHost | Sort-Object Name
#$VMHosts = Get-VMHost | Sort-Object Name

$Today = Get-Date
$TargetMonth = $Today.Month - 1
$TargetYear = $Today.Year
if ($TargetMonth -eq 0) { 
	$TargetMonth = 12
	$TargetYear = $TargetYear - 1
}

$TargetStartDate = [DateTime]"$TargetMonth/1/$TargetYear"
$TargetEndDate = $TargetStartDate.AddMonths(1)

################### Create Excel Components ####################

$EXCEL = New-Object -ComObject Excel.Application
$Workbook = $EXCEL.Workbooks.Add()
$Worksheet = $Workbook.ActiveSheet
$Worksheet.Name = "VMwareHosts"
$Cells = $Worksheet.Cells

$Row = 2
foreach ($VMHost in $VMHosts) {
	
	Write-Host ("Working on: {0}" -f $VMHost.Name)
	$Cells.Item($Row,1) = $VMHost.Name

	$TotalCPUUsage = 0
	$TotalMEMUsage = 0
	$CPUStats = Get-Stat -Entity $VMHost -Stat cpu.usage.average -Start $TargetStartDate -Finish $TargetEndDate | Where { $_.Instance -eq "" }
	$MEMStats = Get-Stat -Entity $VMHost -Stat mem.consumed.average -Start $TargetStartDate -Finish $TargetEndDate
	foreach ($CPUStat in $CPUStats) { $TotalCPUUsage += $CPUStat.Value }
	foreach ($MEMStat in $MEMStats) { $TotalMEMUsage += $MEMStat.Value }
	$VMCPUUsage = [math]::Round(($TotalCPUUsage / $CPUStats.Count) / 100, 2)
	$VMMEMUsage = [math]::Round(($TotalMEMUsage / $MEMStats.Count) / 1048576, 2)
	
	$Cells.Item($Row,2) = $VMCPUUsage
	$Cells.Item($Row,3) = $VMMEMUsage
	$Row++
}

################### Cell Formatting ####################

$Row = 1; $Col = 1;

"VMHost Name","CPU Average","Memory Average" | foreach {
    $Cells.Item($Row,$Col) = $_
    $Cells.Item($Row,$Col).Font.Bold = $True
	$Cells.Item($Row,$Col).Font.Size = 12
    $Col++
}

$Cells.Columns.Item("A:C").AutoFit() | Out-Null
$Range = $Worksheet.Range("C2:C" + $Worksheet.UsedRange.Rows.Count)
$Range.NumberFormat = '#,00 "GB"'
$Range = $Worksheet.Range("B2:B" + $Worksheet.UsedRange.Rows.Count)
$Range.NumberFormat = '0%'
$Worksheet.UsedRange.Borders.Weight = $xlThin
$Worksheet.UsedRange.Borders.LineStyle = $xlContinuous
$Worksheet.UsedRange.Borders.ColorIndex = $xlColorIndexBlack

$LObject = $Worksheet.ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $Worksheet.UsedRange, $null ,[Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes,$null)

################### Save Worksheet & Quit ####################

$FilePath = "D:\Users\oorcunus\Documents\Scripts\VM\MonthlyCPU\ESX_Monthly_Usage_" + $TargetYear + "_" + $TargetMonth + ".xlsx"
$Workbook.SaveAs($FilePath)
$Workbook.Close()
$EXCEL.Quit()