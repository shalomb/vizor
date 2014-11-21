# PowerShell

& sc.exe config W32Time start= auto | Write-Verbose -Verbose
Get-Service w32time | Start-Service -Verbose
sleep 2

gwmi Win32_NetworkAdapterConfiguration | ?{ 
  $_.DNSDomain 
} | ForEach{ 
  $domain=$_.DNSDomain; 
  & NET.EXE TIME /DOMAIN:$domain /SET /YES | Write-Verbose -Verbose 
}

