$environment = "local"
$logFilePath = "C:\dev\git\chl-view\env\Local\PhData\report\logs\GZW.log"
$previousLine = (Get-Item $logFilePath).length

$ProcessingActive = Get-WmiObject Win32_Process -Filter "CommandLine like '%$environment%Sched%'" | Select-Object handle
$waitProcess = Get-WmiObject Win32_Process -Filter "CommandLine like '%$environment%wait%'" | Select-Object handle

if ($ProcessingActive) {
    $body = "processingstats processingstate=1"
    Write-Host $body
}
elseif ($waitProcess) {
    $body = "processingstats processingstate=2"
    Write-Host $body
}
else {
    $body = "processingstats processingstate=0"
    Write-Host $body
}	

Start-Sleep -Seconds 20

$currentLine = (Get-Item $logFilePath).length

if ($currentLine -ne $previousLine) {
    $LogIsUpdating = $true
}

if ($LogIsUpdating -and $null -eq $waitProcess -or $ProcessingActive) {
    $body = "processingstats logwritestate=1"
    Write-Host $body
}
elseif ($waitProcess) {
    $body = "processingstats logwritestate=2"
    Write-Host $body
}
else {
    $body = "processingstats logwritestate=0"
    Write-Host $body
}

$SqlAgentStatus = Get-Service 'SQLAgent$MSSQLSERVER2017'

if ($SqlAgentStatus.Status -eq "Running") {
    $body = "processingstats sqlagentstate=3"
    Write-Host $body
}
elseif ($SqlAgentStatus.Status -eq "Stopped") {
    $StartType = $SqlAgentStatus.StartType 
    if ($StartType -ne "Disabled") {
        $body = "processingstats sqlagentstate=0"
    }
    else {
        $body = "processingstats sqlagentstate=2"
    }
    Write-Host $body
}
elseif ($SqlAgentStatus.Status -eq "StopPending") {
    $body = "processingstats sqlagentstate=1"
    Write-Host $body
}

$SqlServerStatus = Get-Service 'MSSQL$MSSQLSERVER2017'

if ($SqlServerStatus.Status -eq "Running") {
    $body = "processingstats sqlserverstate=3"
    Write-Host $body
}
elseif ($SqlServerStatus.Status -eq "Stopped") {
    $StartType = $SqlServerStatus.StartType 
    if ($StartType -ne "Disabled") {
        $body = "processingstats sqlserverstate=0"
    }
    else {
        $body = "processingstats sqlserverstate=2"
    }
    Write-Host $body
}
elseif ($SqlServerStatus.Status -eq "StopPending") {
    $body = "processingstats sqlserverstate=1"
    Write-Host $body
}