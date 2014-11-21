# Script Module GroupPolicy/GroupPolicy.psm1

Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0


function Disable-AutoRun {                      #M:GroupPolicy
  [CmdletBinding()]
  Param()
  Write-Verbose "Disabling Autorun for all devices."
  & reg.exe add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\Explorer" /f /v NoDriveTypeAutorun /t REG_DWORD /d 0xFF | Write-Verbose
  & reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\Explorer" /f /v NoDriveTypeAutorun /t REG_DWORD /d 0xFF | Write-Verbose
}


function Get-GPResult {                         #M:GroupPolicy
  [CmdletBinding()] Param()
  & gpresult.exe /Z
}


# vim:sw=2:ts=2:et:foldexpr=getline(v\:lnum)=~'^\s*$'&&getline(v\:lnum-1)=~'^\s*$'&&getline(v\:lnum+1)=~'\S'?'<1'\:1:fdm=expr:filetype=ps1:ff=dos:fenc=ASCII

