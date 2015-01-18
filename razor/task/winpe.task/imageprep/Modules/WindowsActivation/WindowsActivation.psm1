# Script Module WindowsActivation/WindowsActivation.psm1

Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0


$slmgr = Join-Path $Env:SystemRoot "System32\slmgr.vbs"


function Get-WindowsActivation {             #M:WindowsActivation
  [CmdletBinding()] Param( )

  $ActivationInfo = New-Object PSObject

  & cscript.exe $slmgr -dlv | %{
    if ($_ -imatch ':') {
      ([String]$Key, [String]$Value) = ([Regex]::Match($_, "^\s*([^:]+)\s*:\s*(.+)$")).Groups[1,2]
      $Key = ($Key -split '\s+' | %{ (Get-Culture).TextInfo.ToTitleCase($_) }) -join ''
      if ( $Key -imatch 'version' )       { [System.Version]$Value = [System.Version][String]$Value }
      if ( $Key -imatch 'trustedtime$' )  { [System.DateTime]$Value = [System.DateTime]::Parse($Value) }
      if ( $Key -imatch 'expiration|interval' ) {
        ([String]$M) = ([Regex]::Match($_, "(\d+) minute")).Groups[1]
        if ( $Key -imatch 'expiration$' ) {
          $D = (Get-Date) + [TimeSpan]::FromMinutes($M)
          $ActivationInfo | Add-Member NoteProperty 'VolumeActivationExpiryDate' $D
        }
        else {
          [TimeSpan]$Value = [TimeSpan]::FromMinutes($M)
        }
      }
      $ActivationInfo | Add-Member NoteProperty $Key $Value
    }
  }

  $ActivationInfo
}

function Get-InstallationId {
  [CmdletBinding()] Param( )

  & cscript.exe $slmgr -dti | %{
    if ( $_ -imatch ':' ) {
      ([String]$Key, [String]$Value) = ([Regex]::Match($_, "^\s*([^:]+)\s*:\s*(.+)$")).Groups[1,2]
      $Value
    }
  }
}

function Get-ExpirationDate {
  [CmdletBinding()] Param( )

  & cscript.exe $slmgr -xpr | %{
    if ( $_ -imatch 'will expire' ) {
      if ( ([String]$Value) = ([Regex]::Match($_, "^.*will expire\s*(.+)$")).Groups[1] ) {
        [DateTime]$Value
      }
    }
  }
}

function Invoke-WindowsActivation {             #M:WindowsActivation
  [CmdletBinding()]
  Param()
  # TODO
  #  * Prerequisites - time on the KMS server and client needs to be in sync, error 0xC004F074
  #    KMS Client Setup Keys - http://technet.microsoft.com/en-us/library/ff793421.aspx
  if ( (gwmi Win32_OperatingSystem).Version -lt 6 ) { # xp/2003
    # TODO: XP doesn't have slmgr.vbs, we need an automatic way of doing this
    & (Join-Path $Env:WINDIR "System32\oobe\msoobe.exe") /a
  } else {
    & cscript.exe $slmgr -ato
  }
}

function Set-KMSServer {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)]
      [String]$Server,
    [Parameter(Mandatory=$True)]
      [UInt16]$Port = 1688
  )

  & cscript.exe $slmgr -skms "${Server}:${Port}"
}

function Invoke-Rearm {
  [CmdletBinding()] Param( )

  & cscript.exe $slmgr -rearm
}

function Install-ProductKey {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)]
      [String]$ProductKey
  )

  & cscript.exe $slmgr -ipk $ProductKey
}

function Invoke-LicenseFileReinstallation {
  [CmdletBinding()] Param( )

  & cscript.exe $slmgr -rilc
}


