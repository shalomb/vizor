# Script Module Robocopy/Robocopy.psm1

Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0

# TODO
#
function Install-ASFSupportLib {                #M:Robocopy
# Generic robocopy installer
  [CmdletBinding()]
  Param()
  Write-Verbose "Installing the ASFSupportLib $ASFSupportLib -> $ASFBin"
  if (-not (Test-Path $ASFBin)) { mkdir -Force $ASFBin | Out-Null }
  Write-Host xcopy /v /e /s /Y $ASFSupportLib $ASFBin
  & xcopy /v /e /s /Y $ASFSupportLib $ASFBin
}


# vim:sw=2:ts=2:et:foldexpr=getline(v\:lnum)=~'^\s*$'&&getline(v\:lnum-1)=~'^\s*$'&&getline(v\:lnum+1)=~'\S'?'<1'\:1:fdm=expr:filetype=ps1:ff=dos:fenc=ASCII

