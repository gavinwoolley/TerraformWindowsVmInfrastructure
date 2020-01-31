$logFilePath = "C:\dev\git\env\Local\report\logs\GZW.log"

$lastLogUpdateTime = ((Get-Item $logFilePath).LastWriteTime).tostring("dd-MM-yyyy HH:mm")

if ($lastLogUpdateTime) {
    $body = "$lastLogUpdateTime"
    Write-Host $body
}
