function Import-ConfigFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ConfigFilePath
    )

    $sRawString = Get-Content $ConfigFilePath | Out-String
    $sStringToConvert = $sRawString -replace '\\', '\\'
    $config = ConvertFrom-StringData $sStringToConvert

    return $config
}

function Get-ProcessingLauncherStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [Parameter(Mandatory = $true)]
        [string] $EnableLogging
    )

    Out-ToConsole -Message "Checking processing launcher status" -EnableLogging $EnableLogging
    
    $ProcessActive = Get-ProcessHandle -Filter "CommandLine like '%$environment%Sched%'"
    $ProcessInWait = Get-ProcessHandle -Filter "CommandLine like '%$environment%wait%Done%'"

    if ($ProcessActive) {
        $Status = 1
    }
    elseif ($ProcessInWait) {
        $Status = 2
    }	
    else { 
        $Status = 0
    }
    return $Status
}

function Start-ContinuousMonitoringForRestart {
    [CmdletBinding()]
    param (
        [ValidateSet('Y', 'N')]
        [Parameter(Mandatory = $true)]
        [string] $EnableLogging,
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [Parameter(Mandatory = $true)]
        [string] $isLogBeingUpdated,
        [Parameter(Mandatory = $true)]
        [int] $waitTimeSeconds,
        [Parameter(Mandatory = $true)]
        [string] $previousLine,
        [Parameter(Mandatory = $true)]
        [string] $logFilePath,
        [Parameter(Mandatory = $true)]
        [int] $LogUpdatedTimeDiffInMinutesThreshold
    )
    
    Out-ToConsole -Message "Monitoring for processing restart" -EnableLogging $EnableLogging
    $Status = Get-ProcessingLauncherStatus -EnableLogging $EnableLogging -environment $environment
    while ($Status -eq 0) {
        Out-ToConsole -Message "Waiting $waitTimeSeconds Seconds for Processing Scheduler to be launched" -EnableLogging $EnableLogging
        Start-Sleep -Seconds $waitTimeSeconds
        $Status = Get-ProcessingLauncherStatus -EnableLogging $EnableLogging -environment $environment
    }
  #  while ($Status -eq 2) {
  #      Out-ToConsole -Message "Processing Scheduler is up and waiting for the overnight run to be launched" -EnableLogging $EnableLogging
  #      Start-Sleep -Seconds $waitTimeSeconds
  #      $Status = Get-ProcessingLauncherStatus -EnableLogging $EnableLogging -environment $environment
  #  }
    Send-Updates -EnableLogging $EnableLogging -StatusMessage "Up"
    Start-ContinuousMonitoringForProcessingLauncher @MonitorParams
}

function Out-ToConsole {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Message,
        [ValidateSet('Y', 'N')]
        [Parameter(Mandatory = $true)]
        [string] $EnableLogging
    )

    $Date = Get-Date
    $output = $Date.ToString('yyyy-MM-dd HH:mm:ss') + ': ' + $message

    if ($EnableLogging -eq "Y") {
        Write-Host $output
        $output | Add-Content "$PSScriptRoot\logFile.txt"
    }
    else {
        Write-Host $output
    }
}

function Start-MonitorForLoggingRestart {
    [CmdletBinding()]
    param (
        [ValidateSet('Y', 'N')]
        [Parameter(Mandatory = $true)]
        [string] $isLogBeingUpdated,
        [ValidateSet('Y', 'N')]
        [Parameter(Mandatory = $true)]
        [string] $EnableLogging,
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [Parameter(Mandatory = $true)]
        [int] $waitTimeSeconds,
        [Parameter(Mandatory = $true)]
        [string] $previousLine,
        [Parameter(Mandatory = $true)]
        [string] $logFilePath,
        [Parameter(Mandatory = $true)]
        [int] $LogUpdatedTimeDiffInMinutesThreshold
    )

    Out-ToConsole -Message "Monitoring for logging restart" -EnableLogging $EnableLogging
    while ($isLogBeingUpdated -eq "N") {
        Out-ToConsole -Message "Waiting for logging to restart" -EnableLogging $EnableLogging
        Start-Sleep -Seconds 15
        $waitProcess = Get-ProcessHandle -filter "CommandLine like '%$environment%wait%JobExecute%'"
        if ($null -ne $waitProcess) {
            Out-ToConsole -Message "Wait Process not running" -EnableLogging $EnableLogging
            Send-Updates -EnableLogging $EnableLogging -StatusMessage "Up"
            Start-ContinuousMonitoringForProcessingLauncher @MonitorParams
        }		
        $isLogBeingUpdated = Test-IfInWaitProcessOrLogNotUpdated -previousLine $previousLine -environment $environment -isLogBeingUpdated $isLogBeingUpdated -logFilePath $logFilePath -LogUpdatedTimeDiffInMinutesThreshold $LogUpdatedTimeDiffInMinutesThreshold
        Start-Sleep -m $waitTimeSeconds
    }
    Send-Updates -EnableLogging $EnableLogging -StatusMessage "Up"
}

function Start-ContinuousMonitoringForProcessingLauncher {
    [CmdletBinding()]
    param (
        [ValidateSet('Y', 'N')]
        [Parameter(Mandatory = $true)]
        [string] $EnableLogging,
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [ValidateSet('Y', 'N')]
        [Parameter(Mandatory = $true)]
        [string] $isLogBeingUpdated,
        [Parameter(Mandatory = $true)]
        [string] $previousLine,
        [Parameter(Mandatory = $true)]
        [string] $logFilePath,
        [Parameter(Mandatory = $true)]
        [int] $waitTimeSeconds,
        [Parameter(Mandatory = $true)]
        [int] $LogUpdatedTimeDiffInMinutesThreshold
    )

    Out-ToConsole -Message "Monitoring for processing launcher" -EnableLogging $EnableLogging
    $Status = Get-ProcessingLauncherStatus -EnableLogging $EnableLogging -environment $environment
    while ($Status -eq 1 -or $Status -eq 2) {
        Start-Sleep -Seconds $waitTimeSeconds
        $Status = Get-ProcessingLauncherStatus -EnableLogging $EnableLogging -environment $environment
        $isLogBeingUpdated = Test-IfInWaitProcessOrLogNotUpdated -previousLine $previousLine -environment $environment -isLogBeingUpdated $isLogBeingUpdated -logFilePath $logFilePath -LogUpdatedTimeDiffInMinutesThreshold $LogUpdatedTimeDiffInMinutesThreshold 
        if ($isLogBeingUpdated -eq "N" -and $Status -eq 1) {
            Send-Updates -EnableLogging $EnableLogging -StatusMessage "Down"
            Start-MonitorForLoggingRestart -environment $environment -EnableLogging $EnableLogging -waitTime $waitTimeSeconds -isLogBeingUpdated $isLogBeingUpdated -previousLine $previousLine -logFilePath $logFilePath -LogUpdatedTimeDiffInMinutesThreshold $LogUpdatedTimeDiffInMinutesThreshold	
        }
        else {
            Write-Debug "Processing Launcher is running and the log is being updated"
        }
    }
    Send-Updates -EnableLogging $EnableLogging -StatusMessage "Down"	
    Start-ContinuousMonitoringForRestart @MonitorParams
}

function Get-ProcessHandle {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $filter
    )

    $processHandle = Get-WmiObject Win32_Process -Filter $filter | Select-Object handle
    return $processHandle
}

function Test-IfInWaitProcessOrLogNotUpdated {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $previousLine,
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [ValidateSet('Y', 'N')]
        [Parameter(Mandatory = $true)]
        [string] $isLogBeingUpdated,
        [Parameter(Mandatory = $true)]
        [string] $logFilePath,
        [Parameter(Mandatory = $true)]
        [int] $LogUpdatedTimeDiffInMinutesThreshold
    )
    
    $waitProcess = Get-ProcessHandle -filter "CommandLine like '%$environment%wait%Working%'"
    
    $currentLine = (Get-Item $logFilePath).length
    if ($currentLine -ne $previousLine) {
        Write-Debug "Log File is still being updated"
        $previousLine = $currentLine
        $lastLogUpdate = (Get-Item $logFilePath).LastWriteTime
        $isLogBeingUpdated = "Y"
    }

    if ($null -eq $waitProcess) {	
        Write-Debug "Not in Wait Process, checking if Log File last line has changed in last $timeDiffInMinutes minutes"

        $timeDiffInMinutes = ((GET-DATE) - $lastLogUpdate).TotalMinutes        
        if ($timeDiffInMinutes -gt $LogUpdatedTimeDiffInMinutesThreshold) {
            Write-Debug "Log File has NOT been updated for $timeDiffInMinutes minutes"
            $isLogBeingUpdated = "N"
        }
    }
    else { 
        Write-Debug "Currently in WAIT Process"
    }
    return $isLogBeingUpdated
}

function Send-Updates {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $EnableLogging,
        [ValidateSet('Up', 'Down')]
        [Parameter(Mandatory = $true)]
        [String] $StatusMessage
    )
    Out-ToConsole -Message "Setting status as $StatusMessage" -EnableLogging $EnableLogging
    Update-GeckoBoard @GeckoboardParams -StatusMessage $StatusMessage
    Send-Email @SendEmailParams -StatusMessage "$($StatusMessage.ToUpper())"
}

function Update-GeckoBoard {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $StatusMessage,
        [Parameter(Mandatory = $true)]
        [String] $apikey,
        [string] $geckoPushUrl1,
        [string] $geckoPushUrl2,
        [Parameter(Mandatory = $true)]
        [string] $EnableLogging
    )
    
    $jsonstream = @"
	{
		"api_key":"$apikey",
		"data": {
			"status":"$StatusMessage","downTime": "","responseTime": ""
		}
	}	
"@

    $client = new-object system.net.webclient
	
    if ($geckoPushUrl1) {	
        Out-ToConsole -Message "Updating Geckboard with Status $StatusMessage" -EnableLogging $EnableLogging
        $client.UploadString($geckoPushUrl1, $jsonstream)
    }
    if ($geckoPushUrl2) { 	
        Out-ToConsole -Message "Updating Geckboard with Status $StatusMessage" -EnableLogging $EnableLogging
        $client.UploadString($geckoPushUrl2, $jsonstream)
    }
}

function Send-Email {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('YES', 'NO')]
        [string] $sendEmail,
        [Parameter(Mandatory = $true)]
        [string] $emailFromAddress,
        [Parameter(Mandatory = $true)]
        [string] $emailToAddress,
        [Parameter(Mandatory = $true)]
        [string] $SmtpServer,
        [Parameter(Mandatory = $true)]
        [string] $SmtpPort,
        [Parameter(Mandatory = $true)]
        [string] $SmtpUser,
        [Parameter(Mandatory = $true)]
        [string] $SmtpPassword,
        [Parameter(Mandatory = $true)]
        [string] $StatusMessage,
        [Parameter(Mandatory = $true)]
        [string] $environment,
        [Parameter(Mandatory = $true)]
        [string] $client
    )
    if ($sendEmail -eq "YES") {
        Write-Debug "Trying to send email"
        $subject = "$environment Processing is $($statusMessage.ToUpper()) on $client"
        $body = "$environment Processing is $($statusMessage.ToUpper()) on $client"
	
        try	{
            $smtp = New-Object System.Net.Mail.SmtpClient($SMTPServer, $SMTPPort);			
            $smtp.EnableSSL = $true
            $smtp.Credentials = New-Object System.Net.NetworkCredential($SmtpUser, $SmtpPassword);
            $smtp.Send($emailFromAddress, $emailToAddress, $subject, $body);
            Write-Debug "Email Sent"
        }
        catch { 
            Write-Debug "Email sending failed"
            "Exception caught in CreateTestMessage: {0}" -f $Error.ToString() 
        } 
    }
}