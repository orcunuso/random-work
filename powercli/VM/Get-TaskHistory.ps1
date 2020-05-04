# *************************************************************************************************
#
# Powershell script that lists tasks history
#
# USAGE: .\Get-TaskHistory.ps1
#
# ASSUMPTIONS: Already connected to vCenter Server
#
# *************************************************************************************************

$hours = 24 
$start = (Get-Date).AddHours(-$hours)
$tasknumber = 999 	
# Windowsize for task collector 
$taskMgr = Get-View TaskManager

$tFilter = New-Object VMware.Vim.TaskFilterSpec
$tFilter.Time = New-Object VMware.Vim.TaskFilterSpecByTime
$tFilter.Time.beginTime = $start
$tFilter.Time.timeType = "startedTime" 
$tFilter.Entity = New-Object VMware.Vim.TaskFilterSpecByEntity

$Entity = Get-VM -Name TestServer
$moRef = $Entity.Id
$tFilter.Entity = $moRef

$tCollector = Get-View ($taskMgr.CreateCollectorForTasks($tFilter))

$dummy = $tCollector.RewindCollector
$tasks = $tCollector.ReadNextTasks($tasknumber)

while($tasks){
    foreach($task in $tasks){
        New-Object PSObject -Property @{
            Name = $task.EntityName
            Task = $task.DescriptionId
            Start = $task.StartTime
            Finish = $task.CompleteTime
            Result = $task.State
            User = $task.Reason.UserName
        }
    }
}
$tasks = $tCollector.ReadNextTasks($tasknumber)

# By default 32 task collectors are allowed. Destroy this task collector. 
$tCollector.DestroyCollector()