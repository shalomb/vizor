# Script Module XenTools/XenTools.psm1


Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0


function Test-IsXenVM {
  [CmdletBinding()]
  Param()
  (Gwmi Win32_SystemEnclosure).Manufacturer -imatch '^Xen$'
}


function Assert-IsXenVM {
  [CmdletBinding()]
  Param(
    [Switch]$NoThrow
  )
  if ( -not(Test-IsXenVM) ) {
    $ErrMsg  = "Not a Xen VM."
    if ( $NoThrow ) {
      Write-Warning $ErrMsg
    } else {
      Throw $ErrMsg
    }
  }
  return $True
}


function Get-XenToolsVersion {
  [CmdletBinding()]
  Param()

  if ( Test-Path 'HKLM:\Software\Citrix\XenTools' ) {
    $XenTools = Get-ItemProperty 'HKLM:\Software\Citrix\XenTools'
    [System.Version](@($XenTools.MajorVersion,$XenTools.MinorVersion,$XenTools.MicroVersion,$Xentools.BuildVersion) -join ".")
  }
  else {
    throw "Xentools not installed or legacy detection not supported."
  }
}


function Assert-XenToolsIsInstalled {           #M:XenTools
  [CmdletBinding()]
  Param(
    [Switch]$NoThrow
  )

  [Boolean]$TestResult = $False
  try {
    $TestResult = Test-XenToolsInstallation -Verbose:$VerbosePreference
    Write-Verbose "Test Result : $TestResult"
  } catch {
    $ErrMsg = "Test-XenToolsInstallation failed one of more checks. $_"
    if ( $NoThrow ) {
      Write-Warning $ErrMsg
    }
    else {
      throw $ErrMsg
    }
  }
  return $TestResult
}


function Test-XenToolsInstallation {            #M:XenTools
  # Only for > 6.1 (Tampa)
  [CmdletBinding()]
  Param(
    [Switch]$Extended,
    [Switch]$DescribeError
  )

  [Boolean]$XenToolsTest = $True  # Innocent till proven guilty

  if ( $Extended ) {
    $XenServerProducts = Gwmi -Class Win32_Product | ?{ $_.Name -imatch 'xen(\sserver)?' }
    $XenToolsTest = $XenToolsTest -band [Boolean]($XenServerProducts)
    Write-Verbose "Test installed XenTools products. ($XenToolsTest)."
  } else {
    # TODO : This should be refactored to not do a hardcoded match
    #        Also consider the state of the xen services/processes
    #        i.e. Hybrid-extended
    $XenToolsTest = [Boolean](((Get-XenPVInstallStatus).InstallStatus) -eq 'Installed')
    return $XenToolsTest
  }

  $InstallStatus = $False
  try {
    if ($Path = Get-ItemProperty 'HKLM:\Software\Citrix\XenToolsInstaller' -ea 0) {
      $InstallStatus = $Path | Select-Object -ExpandProperty InstallStatus
    }
  } catch {
  }

  # if ( ($InstallStatus -eq $False) -and ([Boolean](Get-Service XenPVInstall -ea 0)) ) {
  #   $InstallStatus = 'FailedXenPVInstall'
  # }

  $XenToolsInstallStatus = if ( ($InstallStatus -eq $False) -or ($InstallStatus -imatch 'Failed|Starting') ) { $False } else { $True }
  $XenToolsTest = $XenToolsTest -band [Boolean]($XenToolsInstallStatus)
  Write-Verbose "Test XenTools installer status '$InstallStatus/$XenToolsInstallStatus'. ($XenToolsTest)"

  # if ( -not($XenToolsTest) -and $DescribeError ) {
  #   return $InstallStatus
  # }

  $XenToolsInstallDir = $False
  if ($Path = Get-ItemProperty 'HKLM:\Software\Citrix\XenTools' -ea 0) {
    $XenToolsInstallDir = $Path | Select-Object -ExpandProperty Install_Dir -ea 0
  }

  $XenToolsTest = $XenToolsTest -band [Boolean](Test-Path $XenToolsInstallDir)
  Write-Verbose "Test XenTools install directory '$XenToolsInstallDir'. ($XenToolsTest)"

  # "",".","Installer","XenBus","XenIface","XenNet","XenVbd","XenVif" | %{
  #   $XenToolsTest = $XenToolsTest -band (Test-Path (Join-Path $XenToolsInstallDir $_))
  #   Write-Verbose "Test XenTools install subdir '$_'. ($XenToolsTest)."
  # }

  $XenToolsTest = $XenToolsTest -band [Boolean](Get-Process XenGuestAgent -ea 0)
  Write-Verbose "Test for running XenGuestAgent process. ($XenToolsTest)"

  $XenToolsTest = $XenToolsTest -band [Boolean](Get-Service XenSvc -ea 0)
  Write-Verbose "Test for the XenSvc service. ($XenToolsTest)"

  $XenToolsTest = $XenToolsTest -band [Boolean](Get-Service XenSvc -ea 0 | ?{ $_.Status -eq 'Running' })
  Write-Verbose "Test for the XenSvc service in a running state. ($XenToolsTest)"

  # $XenToolsTest = $XenToolsTest -band [Boolean](Get-Service XenPVInstall)
  # Write-Verbose "Test for the XenPVInstall service. ($XenToolsTest)"

  return $XenToolsTest
}


function Find-XenToolsInstaller {
  [CmdletBinding()]
  Param(
    [String]$Path,
    [Switch]$ScanCDRom = $True
  )

  $InstallerPath = if ( $Path ) {
    if ( Test-Path $Path ) {
      if (Test-Path($InstallerWizard = Join-Path $Path "installwizard.msi")) { # For >= 6.1 (Tampa)
        Write-Verbose "  Found XenTools ($InstallerWizard)"
        Write-Output $InstallerWizard
      }
      elseif (Test-Path ($XenSetup = Join-Path $Path "xensetup.exe")) {  # For <= 6.0 (Sanibel)
        Write-Verbose "  Installing Legacy XenTools ($XenSetup)"
        Write-Output $XenSetup
      }
      else  {
        Write-Error "No XenTools installer found under $Path."
      }
    }
    else {
      Write-Error "Path ($Path) does not exist or is inaccessible."
    }
  }
  elseif ( $ScanCDRom ) {
    if ( $CandidateCDRom = Get-CDROMDevice | ?{ Test-Path $_.RootDirectory } ) {
      $CandidateInstaller = $CandidateCDRom | %{
        Write-Verbose "Scanning for XenTools on CD/DVD ROM: $($_.Name) ($($_.VolumeLabel))"
        if ( $Installer = Find-XenToolsInstaller -Path $_.Name -ea 0 ) {
          Write-Output $Installer
        }
      }
      if ( -not( $CandidateInstaller ) ) {
        Write-Error "No candidate installers found after scanning all available CD-ROMs."
      }
      Write-Output $CandidateInstaller
    }
    else {
      Throw "No CD-Rom devices found to be inserted. Aborting .."
    }
  }
  else {
    Write-Error "Unsupported method or no parameters specified."
  }

  if ($InstallerPath) {
    return $InstallerPath
  }

  Throw "No installer path found"
}


function Install-XenTools {                     #M:XenTools
  [CmdletBinding()]
  Param(
    [String] $Path = (Find-XenToolsInstaller),
    [String] $LogFile = (Join-Path $Env:TEMP "xentools-installwizard.msi.$(Get-Date -UFormat %s).log"),
    [Switch] $NoRestart,
    [Switch] $NoEjectCDRom,
    [Switch] $Force
  )

  $InstallStatus = Test-XenToolsInstallation -DescribeError

  if ( ($InstallStatus) -and -not($Force) ) {
    Switch -Regex ($InstallStatus) {
      'Failed|Starting' {
        Write-Warning "Previous XenTools installation failed."
        Write-Warning "  -Force not specified. Attempting to restart installer service."
        Get-Service *Xen* | Restart-Service -Verbose:$VerbosePreference
        return $InstallStatus
      }
      '^True$' {
        Write-Verbose "Xentools appears to be installed."
        return $True
      }
    }
  }

  Write-Verbose "Starting XenTools Installation using $Path"

  $InstallStatus = if ($Path -imatch 'installwizard.msi$') {
    $InstallWizardArgs = @( '/i', $Path, '/norestart', '/quiet', '/passive', '/qr', '/liwearucmopvx!', "$LogFile" )

    Write-Verbose "  'msiexec.exe' $InstallWizardArgs"
    $process = Start-Process -FilePath (Join-Path "$Env:WINDIR\System32" msiexec.exe) -ArgumentList $InstallWizardArgs -wait -PassThru

    if (-not $process){
      throw "Error executing msiexec."
    } else {
      $process | Wait-Process
    }

    Write-Verbose "  MsiExec.exe ExitCode : $($process.ExitCode)"
    Write-Output $process.ExitCode
  }
  elseif ($Path -imatch 'xensetup.exe$') { # TODO: Consider breaking into Install-XenToolsLegacy
    $XenSetup = $Path
    $XenSetupArgs = ('/S', '/norestart')

    Write-Verbose "  '$XenSetup' $XenSetupArgs"
    $process = Start-Process -FilePath $XenSetup -wait -PassThru -ArgumentList $XenSetupArgs

    if (-not $process){
      throw "Error executing '$XenSetup' $XenSetupArgs"
    } else {
      $process | Wait-Process
    }

    Write-Verbose "  ExitCode : $($process.ExitCode)"
    Write-Output $process.ExitCode

    Return # Return immediately, no further validation for legacy tools.
  }
  else {
    Throw "Unsupported/Undefined Path ($Path) to perform XenTools Installation"
  }

  Switch -Regex ( $InstallStatus ) {
    '^0$'  {
      Write-Verbose " Xentools installer service (XenPVInstall) installed successfully. Exit Code : InstallStatus."

      if ( -not($NoEjectCDRom) ) { # Workaround for Cloud to eject CD after install
        if ( ($DriveInfo = ([System.IO.DriveInfo]$Path)).DriveType -imatch 'CDRom' ) {
          Write-Verbose "  Ejecting CD-ROM '$($DriveInfo.VolumeLabel)' ($($DriveInfo.Name))"
          Dismount-CDRomDevice -DriveLetter $DriveInfo.Name -Verbose:$VerbosePreference
        }
      }

      if ( -not($NoRestart) ) {
        ForEach ($i in 0..60) { # Try 60 times (~1 minute) to see if XenPVInstall if ready to reboot
          if ( ($RebootStatus = (Get-XenPVInstallStatus).RebootStatus) -imatch 'RequestReboot' ) {
            Write-Verbose "  {RebootRequestStatus=$RebootStatus; Rebootallowed=$(-not($NoRestart))}"
            if ( -not( $NoRestart ) ) {
              Write-Verbose "  & shutdown.exe -r -t 3"
              Restart-Computer
              & shutdown.exe -r -t 3 -f # Allow function to return
              break
            } else {
              Write-Verbose "  Reboot skipped."
            }
          }
          Write-Host -NoNewLine "."
          sleep 2;
        }
      }
      break
    }
    '^\d+$' {
      $InstallStatus | %{ Write-Warning "  Unexpected Installation Status : $_" }
      throw "Xentools did not install successfully. Exit Code : $($InstallStatus)."
      break
    }
    '.*' {
      $InstallStatus | %{ Write-Warning "  Unexpected Installation Status : $_" }
      throw "Error installing XenTools. Last Installation Status: $($InstallStatus)"
    }
  }
}


function Get-XenPVInstallStatus {
  [CmdletBinding()]
  Param( )

  $OSArchitecture = (Gwmi Win32_OperatingSystem).OSArchitecture

  $InstallStatus = $False
  try {
    if ( $OSArchitecture -imatch '64' ) {
      if (Test-Path ($XTIPath = 'HKLM:\Software\Wow6432Node\Citrix\XenToolsInstaller')) {
        $InstallStatus = gp $XTIPath | Select -ExpandProperty InstallStatus
      }
    }
    elseif ( $OSArchitecture -imatch '32' ) {
      if (Test-Path ($XTIPath = 'HKLM:\Software\Citrix\XenToolsInstaller')) {
        $InstallStatus = gp $XTIPath | Select -ExpandProperty InstallStatus
      }
    }
    else {
      Throw "Unknown architecture ($OSArchitecture)."
    }
  }
  catch {
    Throw "Error retrieving XenPVInstallStatus : $_"
  }

  $Status = New-Object PSObject
  $Status | Add-Member NoteProperty InstallStatus       $InstallStatus
  $Status | Add-Member NoteProperty OSArchitecture      $OSArchitecture

  try {
    $Status | Add-Member NoteProperty RebootStatus      'Unknown'
    if ($cxsis = Gwmi -NameSpace 'root\citrix\xenserver\agent' -Class 'CitrixXenServerInstallStatus' -ea 0) {
      $Status | Add-Member -force NoteProperty RebootStatus      $cxsis.Status
      $Status | Add-Member -force NoteProperty Progress          $cxsis.Progress
      $Status | Add-Member -force NoteProperty MaxProgress       $cxsis.MaxProgress
      $Status | Add-Member -force NoteProperty StatusDisplayText $cxsis.StatusDisplayText
    }
  }
  catch {
    Write-Warning "$_"
  }
  $Status
}


function Uninstall-XenTools {
  [CmdletBinding()]
  Param()
  Throw "Currently unimplemented. Refer to XOP-363."
}



