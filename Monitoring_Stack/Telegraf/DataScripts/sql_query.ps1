Push-Location
$SqlEodState = Invoke-Sqlcmd -Query "select top 1 * from [CHL_Local].dbo.JLOG where jlog060 != '' order by jlog999 desc" -ServerInstance "GZW-LAP\MSSQLSERVER2014"
Pop-Location

if ($SqlEodState.JLOG060) {
    $body = "$($SqlEodState.JLOG010) $($SqlEodState.JLOG060)"
    Write-Host $body
}