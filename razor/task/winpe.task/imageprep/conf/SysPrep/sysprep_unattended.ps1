Set-StrictMode -Version 2
Set-PSDebug -Trace 2

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

& (Join-Path $Env:Windir "System32\sysprep\sysprep.exe") `
  -generalize -oobe -reboot `
  -unattend:(Join-Path $ScriptPath "unattend.xml")
