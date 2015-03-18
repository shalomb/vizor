# PowerShell

Set-StrictMode -Version 2

function Get-DotNetFramework {
  [CmdletBinding()] Param(
    [Version] $Version,
    [Switch]  $System,
    [Switch]  $Environment,
    [Switch]  $HighestVersion,
    [Switch]  $LowestVersion
  )

  if ( $Version ) {
    if ( $Candidate = (Get-DotNetFramework | ?{ ([String]$_.Version) -imatch "^$Version" }) ) {
      return $Candidate
    }
    else {
      return
    }
  }

  if ( $LowestVersion ) {
    return (Get-DotNetFramework | Sort Version | Select -First 1)
  }

  if ( $HighestVersion ) {
    return (Get-DotNetFramework | Sort Version | Select -Last 1)
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
    [String] $SxSSourcePath,
    [Switch] $Online,
    [Switch] $ClientOnly,
    [Switch] $Force
  )

  Write-Verbose "Installing .Net3.5 from $SxSSourcePath"

  if ((Test-DotNetFramework -Version 3.5) -and -not($Force)) {
    Write-Verbose ".Net3.5 appears to be installed. Aborting.."
    return $True
  }

  if ( ((gp 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentVersion   -ieq 6.1) -and `
       ((gp 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').InstallationType -ieq 'Server') ) {
    Import-Module ServerManager -ea 0
    Add-WindowsFeature as-net-framework -Verbose:$VerbosePreference
  }
  elseif ( $SxSSourcePath ) {
    if ( Import-Module ServerManager -ea 0 ) {
      Add-WindowsFeature -Name NET-Framework-Features -Source $SxSSourcePath
    }
    else {
      & dism.exe /online /enable-feature /featurename:NetFX3 /All /Source:$SxSSourcePath /LimitAccess
    }
  }
  elseif ( $Online ) {
    $Url = if ( $ClientOnly ) {
      'http://download.microsoft.com/download/c/d/c/cdc0f321-4f72-4a08-9bac-082f3692ecd9/DotNetFx35Client.exe'
    } else {
      'http://download.microsoft.com/download/2/0/E/20E90413-712F-438C-988E-FDAA79A8AC3D/dotnetfx35.exe'
    }

    $File = Join-Path $Env:Temp ($Url -split '\/')[-1]
    Write-Warning "Downloading '$Url' to '$File'"
    (New-Object Net.WebClient).DownloadFile($Url, $File)

    $Args = if ( $ClientOnly ) {
      @( '/lang:enu', '/passive', '/norestart' )
    } else {
      @( '/qb', '/norestart' )
    }
    Start-Process -Wait $File $Args -NoNewWindow
  }
}

function Install-DotNet4 {
  [CmdletBinding()] Param(
    [Switch] $ClientOnly,
    [Switch] $ServerCore,
    [Switch] $Force
  )

  if ((Test-DotNetFramework -Version 4.0) -and -not($Force)) {
    Write-Verbose ".Net 4.0 appears to be installed. Aborting.."
    return $True
  }

  $Url = if ( $ClientOnly ) {
    'http://download.microsoft.com/download/5/6/2/562A10F9-C9F4-4313-A044-9C94E0A8FAC8/dotNetFx40_Client_x86_x64.exe'
  } elseif ( $ServerCore ) {
    'http://download.microsoft.com/download/3/6/1/361DAE4E-E5B9-4824-B47F-6421A6C59227/dotNetFx40_Full_x86_x64_SC.exe'
  } else {
    'http://download.microsoft.com/download/9/5/A/95A9616B-7A37-4AF6-BC36-D6EA96C8DAAE/dotNetFx40_Full_x86_x64.exe'
  }

  $File = Join-Path $Env:Temp ($Url -split '\/')[-1]
  Write-Warning "Downloading '$Url' to '$File'"
  (New-Object Net.WebClient).DownloadFile($Url, $File)

  Start-Process -Wait $File @('/q', '/passive', '/norestart') -NoNewWindow
}

Export-ModuleMember *-*
