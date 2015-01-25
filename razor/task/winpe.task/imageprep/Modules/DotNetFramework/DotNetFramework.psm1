# PowerShell

Set-StrictMode -Version 2

function Get-DotNetFramework {
  [CmdletBinding()] Param(
    [Version] $Version,
    [Switch]  $System,
    [Switch]  $Environment
  )

  if ( $Version ) {
    if ( $Candidate = (Get-DotNetFramework | ?{ ([String]$_.Version) -imatch "^$Version" }) ) {
      return $Candidate
    }
    else {
      return
    }
  }

  if ( $Environment ) {
    if ($Ver = [Environment]::Version) {
      return (Get-DotNetFramework -Version ('{0}.{1}' -f $Ver.Major,$Ver.Minor))
    }
  }

  if ( $System ) {
    if ( $Ver = ([System.Runtime.InteropServices.RuntimeEnvironment]::GetSystemVersion()) ) {
      $Ver = ([System.Version]($Ver -replace '^v'))
      return (Get-DotNetFramework -Version ('{0}.{1}' -f $Ver.Major,$Ver.Minor))
    }
    else {
      Throw "Unable to determine determine system runtime version"
    }
  }

  Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse |
  Get-ItemProperty -Name Version -ea 0 |
  ?{ $_.PSChildName -match '^(?![SW])\p{L}' } | %{

    $Result = New-Object -TypeName PSObject

    $Ver        = ([System.Version]($_.Version))
    $VerShort   = '{0}.{1}' -f ($Ver.Major, $Ver.Minor)
    $ItemProperties = Get-ItemProperty $_.PSPath

    if ( $_.PSChildName -imatch '^v[0-9]' ) {
      $Result | Add-Member NoteProperty Name    $_.PSChildName
    }
    else {
      $Result | Add-Member NoteProperty Name    ('v{0} {1}' -f $VerShort, $_.PSChildName)
    }

    $Result | Add-Member NoteProperty Version $Ver


    $Result | Add-Member NoteProperty Installed   ($v = if ($ItemProperties.Install) { $True } else { $False })

    if ( $ItemProperties | Select-Object -ExpandProperty SP -ea 0 ) {
      $Result | Add-Member NoteProperty ServicePack $ItemProperties.SP
    }
    else {
      $Result | Add-Member NoteProperty ServicePack 0
    }

    if ( $ItemProperties | Select-Object -ExpandProperty TargetVersion -ea 0 ) {
      $Result | Add-Member NoteProperty TargetVersion $ItemProperties.TargetVersion
    }
    else {
      $Result | Add-Member NoteProperty TargetVersion $VerShort
    }

    $Result | Add-Member NoteProperty NDPKey  (($_.PSPath -replace '^.*?::') -replace 'HKEY_LOCAL_MACHINE', 'HKLM')

    if ( $ItemProperties | Select-Object -ExpandProperty InstallPath -ea 0 ) {
      $Result | Add-Member NoteProperty InstallPath $ItemProperties.InstallPath
    }
    else {
      if ( Test-Path ($InstallPath = '{0}\Microsoft.NET\Framework\{1}' -f $Env:Windir, $_.PSChildName) ) {
        ;
      } else {
        $InstallPath = $Null
      }
      $Result | Add-Member NoteProperty InstallPath $InstallPath
    }

    $Result
  }

}

function Test-DotNetFramework {
  [CmdletBinding()] Param(
    [System.Version] $Version = [Environment]::Version
  )

  [Boolean](Get-DotNetFramework -Version $Version)
}

function Assert-DotNetFramework {
  [CmdletBinding()] Param(
    [System.Version] $Version = [Environment]::Version
  )

  if ( -not(Test-DotNetFramework -Version $Version) ) {
    Throw "Microsoft.NET Framework Version $Version is not available."
  }
}

function Install-DotNet35 {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)] $SxSSourcePath,
    [Switch] $Force
  )

  Write-Verbose "Installing .Net3.5 from $SxSSourcePath"

  if (-not($Force) -and (Test-DotNet35)) {
    Write-Verbose ".Net3.5 appears to be installed. Aborting.."
    return $True
  }

  if ( Import-Module ServerManager -ea 0 ) {
    Write-Verbose "Installing .Net 3.5 using Windows Roles and Features (ServerManager\Add-WindowsFeature)."
    Add-WindowsFeature -Name NET-Framework-Features -Source $SxSSourcePath
  }
  else {
    Write-Verbose "Installing .Net 3.5 using DISM (dism.exe ... /enable-feature /featurename:NetFX3 ...)"
    & dism.exe /online /enable-feature /featurename:NetFX3 /All /Source:$SxSSourcePath /LimitAccess
  }
}

Export-ModuleMember *-*
