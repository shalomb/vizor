# Script Module CDROM/CDROM.psm1

Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0


function Get-CDROMDevice {                      #M:CDROM
  [CmdletBinding()]
  Param(
    [Alias('VolumeLabelFilter')] 
      [Regex] $VolumeLabel
  )
  if ($VolumeLabel) {
    [System.IO.DriveInfo]::GetDrives() | ?{ $_.VolumeLabel -imatch $VolumeLabel } | ?{ Test-CDROMDevice -DriveLetter ([String]$_.RootDirectory) }
  }
  else {
    [System.IO.DriveInfo]::GetDrives() | ?{ Test-CDROMDevice -DriveLetter ([String]$_.RootDirectory) }
  }

<#
.SYNOPSIS
Get all CDROM devices known to the system.
#>
}


function Test-CDROMDevice {                     #M:CDROM
  [CmdletBinding()]
  Param (
    [System.IO.DriveInfo] $DriveLetter = [String]((Get-CDROMDevice | Select -First 1).RootDirectory),
    [Boolean] $IsReady
  )
  
  if ( $IsReady ) {
    return [Boolean]($DriveLetter.IsReady)
  }

  if ($DriveLetter.DriveType -eq "CDRom") { 
    Test-Path $DriveLetter.RootDirectory 
  } 
  else { return $False }

  <#
.SYNOPSIS
Test if the CDROM Device is inserted and accessible.

.PARAMETER DriveLetter
String representation of the Drive Letter e.g. d: or d:\

.EXAMPLE
Test-CDROMDevice -DriveLetter d:
#>
}
Set-Alias Test-IsCDRomInserted Test-CDROMDevice


function Dismount-CDROMDevice {                 #M:CDROM
  [CmdletBinding()] Param (
    [System.IO.DriveInfo]
      [ValidateScript({Test-CDROMDevice -DriveLetter $_})] $DriveLetter,
    [Switch] $All = $True
  )

  if ( $DriveLetter ) {
    try {
      $ShellApplication = New-Object -com Shell.Application
      $MyComputer = $ShellApplication.Namespace(17)
      $Drive = $MyComputer.ParseName($DriveLetter)
      if ( (Gwmi Win32_OperatingSystem).Version -imatch '^5.1' ) {
        $Eject = $Drive.Verbs() | ?{ $_.Name -imatch 'e.*ject' } | %{$_.Name}
      } else {
        $Eject = "Eject"
      }

      $c=0; while (Get-CDROMDevice | %{Test-CDROMDevice -DriveLetter $_}) {
        Write-Verbose "Ejecting CD-ROM Device $DriveLetter ($Eject $($Drive.Name))"
        $Drive.InvokeVerb($Eject)
        $c++
        if ( $c -gt 16 ) {
          Throw "Unable to eject CD-ROM after $c tries";
        }
      }  # Workaround for Vista
      [System.Runtime.Interopservices.Marshal]::ReleaseComObject($ShellApplication)
      Remove-Variable ShellApplication
    }
    catch [Exception] {
      Write-Error "Error dismounting CD-ROM Device"
    }
  }
  elseif ( $All ) {
    Get-CDROMDevice | %{ Dismount-CDROMDevice -DriveLetter ([String]$_.RootDirectory) }
  }

<#
.SYNOPSIS
Eject a set of CDROM devices

.DESCRIPTION
Eject a set of CDROM devices. This is currently a best-effort-only operation due to the
limitation of the underlying COM calls and differences across platforms.

.EXAMPLE
Dismount-CDROMDevice -DriveLetter d:
#>
}



# vim:sw=2:ts=2:et:foldexpr=getline(v\:lnum)=~'^\s*$'&&getline(v\:lnum-1)=~'^\s*$'&&getline(v\:lnum+1)=~'\S'?'<1'\:1:fdm=expr:filetype=ps1:ff=dos:fenc=ASCII

