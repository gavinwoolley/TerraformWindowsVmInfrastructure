New-Item -Path "C:\dev\telegraf" -ItemType Directory -Force
Invoke-WebRequest "https://dl.influxdata.com/telegraf/releases/telegraf-1.13.0_windows_amd64.zip" -OutFile "C:\dev\telegraf\telegraf.zip" -UseBasicParsing
Expand-Archive -Path "C:\dev\telegraf\telegraf.zip" -DestinationPath  "C:\dev\telegraf\telegrafExtracted\"

$serverListToInstalOn = @(
	'localhost'
)

$serverListToInstalOn | % {
	Write-Host "$($_)..."
	Write-Host "..Create folders and copy files..."

	$ProgDir = Get-Item -Path "C:\Program Files\telegraf"
	$MaintDir = Get-Item -Path "C:\DBOps"
	
	if ($null -eq $ProgDir){
		 New-Item -Path "C:\Program Files\telegraf" -ItemType Directory -Force
	}
	
	if ($null -eq $MaintDir){
		 New-Item -Path "C:\DBOps" -ItemType Directory -Force
	}

    Copy-Item -Path "C:\dev\git\Monitoring\Monitoring_Stack\telegraf.conf" -Destination "c:\Program Files\telegraf\" -Force
    Copy-Item -Path "C:\dev\telegraf\telegrafExtracted\telegraf\telegraf.exe" -Destination "c:\Program Files\telegraf\" -Force
	Copy-Item -Path "C:\dev\git\Monitoring\Monitoring_Stack\Start-Telegraf.ps1" -Destination "c:\DBops\Start-Telegraf.ps1" -Force

	Invoke-Command -ComputerName localhost -ScriptBlock {
		Write-Host '..Install service...'
		Stop-Service -Name telegraf -ErrorAction SilentlyContinue
		& "c:\program files\telegraf\telegraf.exe" --service install -config "c:\program files\telegraf\telegraf.conf"
		SC.EXE Config telegraf Start=Delayed-Auto
		Start-Service -Name telegraf
		Start-Sleep 90
		
		# Make sure it starts
		$service = Get-Service | Where-Object {$_.Status -eq "Running" -and $_.Name -eq "telegraf"}
		While($service.count -eq 0) {
    			Start-Service -Name "telegraf"
    			Start-Sleep 90
    			$service = Get-Service | Where-Object {$_.Status -eq "Running" -and $_.Name -eq "telegraf"}
		}

		Write-Host 'Setup job to make sure it autostarts...'
		#Create job to start job on startup
		$trigger = New-JobTrigger -AtStartup -RandomDelay 00:00:30
		Register-ScheduledJob -Trigger $trigger -FilePath C:\DBOps\Start-Telegraf.ps1 -Name Start-Telegraf
	}
}