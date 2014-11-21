# Script Module DDNS/DDNS.psm1

Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0

function Set-DHCPDatabaseCleanupInterval {
  [CmdletBinding()]
  Param(
    [TimeSpan]$Interval
  )
  & netsh.exe dhcp set databasecleanupinterval $Interval.TotalMinutes
}

function Set-DHCPLeaseExtensionDuration {
  [CmdletBinding()]
  Param(
    [TimeSpan]$Duration
  )
  "HKLM\System\CurrentControlSet\Services\DHCPServer\Parameters\LeaseExtension"
}

function Get-DHCPv4Server {
  [CmdletBinding()]
  Param()
  & netsh.exe dhcp show server
}

function Add-DHCPv4Server {
  [CmdletBinding()]
  Param(
    [String]$ServerFQDN,
    [String]$ServerIP
  )
  & netsh.exe dhcp add server $ServerFQDN $ServerIP
}


# vim:sw=2:ts=2:et:foldexpr=getline(v\:lnum)=~'^\s*$'&&getline(v\:lnum-1)=~'^\s*$'&&getline(v\:lnum+1)=~'\S'?'<1'\:1:fdm=expr:filetype=ps1:ff=dos:fenc=ASCII

