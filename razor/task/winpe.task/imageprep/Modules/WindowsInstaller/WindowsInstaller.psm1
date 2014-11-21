
function Get-MsiProductVersion {
  [CmdletBinding()]
  param (
      [Parameter(Mandatory=$true)]
      [ValidateScript({$_ | Test-Path -PathType Leaf})]
      [string]
  :q
  $Path
  )
  function Get-Property ($Object, $PropertyName, [object[]]$ArgumentList) {
    return $Object.GetType().InvokeMember(
        $PropertyName, 'Public, Instance, GetProperty', $null, $Object, $ArgumentList)
  }

  function Invoke-Method ($Object, $MethodName, $ArgumentList) {
    return $Object.GetType().InvokeMember(
        $MethodName, 'Public, Instance, InvokeMethod', $null, $Object, $ArgumentList)
  }

  $ErrorActionPreference = 'Stop'
  Set-StrictMode -Version Latest

  #http://msdn.microsoft.com/en-us/library/aa369432(v=vs.85).aspx
  $msiOpenDatabaseModeReadOnly = 0
  $Installer = New-Object -ComObject WindowsInstaller.Installer

  $Database = Invoke-Method $Installer OpenDatabase @($Path, $msiOpenDatabaseModeReadOnly)

  # $View = Invoke-Method $Database OpenView @("SELECT Value FROM Property WHERE Property='ProductVersion'")
  $View = Invoke-Method $Database OpenView @("SELECT * FROM Property")

  Invoke-Method $View Execute

  $Record = Invoke-Method $View Fetch
  $Record | fl *

  if ($Record) {
    Write-Output (Get-Property $Record StringData 0)
    Write-Output (Get-Property $Record StringData 1)
    Write-Output (Get-Property $Record StringData 2)
    Write-Output (Get-Property $Record StringData 3)
  }

  Invoke-Method $View Close @()
  Remove-Variable -Name Record, View, Database, Installer

<#
.SYNOPSIS
Get the version number of an MSI

.URL
https://gist.github.com/jstangroome/913062
#>

}
