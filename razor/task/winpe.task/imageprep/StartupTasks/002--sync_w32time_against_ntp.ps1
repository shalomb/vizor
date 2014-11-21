# PowerShell

& sc.exe config W32Time start= auto | Write-Verbose -Verbose
Get-Service w32time | Start-Service -Verbose
sleep 2

& w32tm.exe /resync /rediscover /nowait | Write-Verbose -Verbose

