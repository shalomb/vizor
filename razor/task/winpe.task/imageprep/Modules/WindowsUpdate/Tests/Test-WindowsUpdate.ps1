$ErrorActionPreference="Continue"
$DebugPreference = $Global:VerbosePreference = "Continue"
# Set-PSDebug -trace 1
Write-Host "VerbosePreference is : " $VerbosePreference

Write-Host $PSModulePath;
Set-Service -Name wuauserv -StartupType Manual
Start-Service -Name wuauserv

$PSModulePath='\\controller\public';
Import-Module \\controller\public\WindowsUpdate -Force -Verbose;

Write-Host -Foregroundcolor magenta "Test Case  .. DownloadOnly"
Search-WindowsUpdate -Verbose | Install-WindowsUpdate -Verbose -DownloadOnly

Write-Host -Foregroundcolor magenta "Test Case  .. Install"
Search-WindowsUpdate -Verbose -ImportantOnly | Install-WindowsUpdate -Verbose
return


$Null,
"-History",
"-History | Select Date, Title",
"-ImportantOnly",
"-All",
"-ImportantOnly -All" `
| %{ 
  Write-Host -Foregroundcolor magenta "Test Case .. Search-WindowsUpdates $_"
  if ($_) {
    try {
      Invoke-Expression "Search-WindowsUpdates $_" > $Null
    } catch [Exception] {
      Write-Host -Foregroundcolor red "Error: $_" 
    }
  } else {
    Search-WindowsUpdates > $Null
  }
}

Write-Host -Foregroundcolor magenta "Test Case  .. Search-WindowsUpdates -Verbose | Install-WindowsUpdates -Verbose"
Search-WindowsUpdates -Verbose | Install-WindowsUpdates -Verbose -DownloadOnly

$Null,
"-History",
"-ImportantOnly -DownloadOnly",
"-ImportantOnly",
"-All -DownloadOnly",
"-ImportantOnly -All" `
| %{
  Write-Host -Foregroundcolor magenta "Test Case .. Install-WindowsUpdates $_"
  if ($_) {
    try {
      Invoke-Expression "Install-WindowsUpdates $_" > $Null
    } catch [Exception] {
      Write-Host -Foregroundcolor red "Error: $_" 
    }
  } else {
    Install-WindowsUpdates > $Null
  }
}
# vim:filetype=ps1
