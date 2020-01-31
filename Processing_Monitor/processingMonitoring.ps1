Import-Module $PSScriptRoot\Monitoring -Force

$ConfigFilePath = "$PSScriptRoot\monitor.properties"
$Config = Import-ConfigFile -ConfigFilePath $ConfigFilePath

$previousLine = (Get-Item $config.log_file_path).length
$isLogBeingUpdated = "Y" 

$Status = Get-ProcessingLauncherStatus -environment $Config.environment -EnableLogging $Config.Enable_Logging

$global:MonitorParams = @{
	waitTimeSeconds                      = $Config.wait_time_seconds;
	EnableLogging                        = $config.enable_logging;
	environment                          = $config.environment;
	isLogBeingUpdated                    = $isLogBeingUpdated;
	LogUpdatedTimeDiffInMinutesThreshold = $Config.log_updated_time_diff_in_minutes_threshold;
	logFilePath                          = $config.log_file_path;
	previousLine                         = $previousLine;
}

$global:GeckoboardParams = @{
	apikey        = $Config.geckoboard_account_api_key;
	geckoPushUrl1 = $Config.gecko_push_url1;
	geckoPushUrl2 = $Config.gecko_push_url2;
	EnableLogging = $Config.Enable_Logging;
}

$global:SendEmailParams = @{
	sendEmail        = $Config.send_email;
	emailFromAddress = $Config.email_from_address;
	emailToAddress   = $Config.email_to_address;
	SmtpServer       = $Config.smtp_server;
	SmtpPort         = $Config.smtp_port;
	SmtpUser         = $Config.smtp_user;
	SmtpPassword     = $Config.smtp_password;
	environment      = $config.environment;
	client           = $Config.client;
}

if ($Status -eq 0) {
	Out-ToConsole -Message "Processing is Down at monitor start" -EnableLogging $Config.enable_logging
	Update-GeckoBoard @GeckoboardParams -StatusMessage "Down"
	Send-Email @SendEmailParams	-StatusMessage "Down"
	Start-ContinuousMonitoringForRestart @MonitorParams   
}

else {
	Out-ToConsole -Message "Processing is Up at monitor start" -EnableLogging $Config.enable_logging
	Update-GeckoBoard @GeckoboardParams -StatusMessage "Up"
	Send-Email @SendEmailParams	-StatusMessage "Up"
	Start-ContinuousMonitoringForProcessingLauncher @MonitorParams
}