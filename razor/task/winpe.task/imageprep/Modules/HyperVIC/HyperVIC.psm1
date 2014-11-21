# Script Module HyperVIC/HyperVIC.psm1


Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0


function Test-IsHyperVVM {
  [CmdletBinding()]
  Param()
  (Gwmi Win32_SystemEnclosure).Manufacturer -imatch '^Microsoft Corporation'
}


function Get-IntegrationServicesVersion {
  [CmdletBinding()]
  Param()

  [System.Version](Get-ItemProperty "HKLM:\Software\Microsoft\Virtual Machine\Auto").IntegrationServicesVersion
}


function Test-HyperVIntegrationServicesIsInstalled {
  [CmdletBinding()]
  Param()

  $Result = @()

  try {
    $Result += [Boolean](Get-IntegrationServicesVersion)
    Write-Verbose       "Test for  Integration Services ($Result)"
  } catch {}

  $Result += [Boolean](Get-Service vmicheartbeat  -ea 0)
  Write-Verbose         "Test for  vmicheartbeat ($Result)"
  $Result += [Boolean](Get-Service vmickvpexchange -ea 0)
  Write-Verbose         "Test for  vmickvpexchange ($Result)"
  $Result += [Boolean](Get-Service vmicrdv        -ea 0)
  Write-Verbose         "Test for  vmicrdv ($Result)"
  $Result += [Boolean](Get-Service vmictimesync   -ea 0)
  Write-Verbose         "Test for  vmictimesync ($Result)"
  $Result += [Boolean](Get-Service vmicvss        -ea 0)
  Write-Verbose         "Test for  vmicvss ($Result)"
  
  -not($Result -contains $False)
}


function Install-HyperVIntegrationServices {    #M:HyperVIC
  [CmdletBinding()]
  Param(
    [Switch]$NoRestart,
    [Switch]$Quiet
  )

  $CpuArch = Switch ((Gwmi Win32_OperatingSystem).OSArchitecture) {
    '32-bit'  { "x86"     ;break; }
    '64-bit'  { "amd64"   ;break; }
    *         { "unknown" }
  }

  $RootDirectory = (Get-CDROMDevice -VolumeLabelFilter "VMGUEST").RootDirectory
  Write-Verbose  "Installing Hyper-V Integration Service ($CpuArch) from $RootDirectory"

  if ( Test-Path ($Setup = Join-Path $RootDirectory "support\$CpuArch\setup.exe") ) {
    $SetupArgs   = @('')
    if ( $Quiet     ) { $SetupArgs   = ('/quiet')    }
    if ( $NoRestart ) { $SetupArgs += ('/norestart') }

    if ($SetupArgs) {
      Write-Verbose "Invoking '$Setup' $SetupArgs"
      $process = Start-Process -FilePath $Setup -ArgumentList $SetupArgs -wait -PassThru
    } 
    else {
      Write-Verbose "Invoking '$Setup' $SetupArgs"
      $process = Start-Process -FilePath $Setup -wait -PassThru
    }
    if (-not $process){
      Throw "Error executing '$Setup $args'"
    } 
    else {
      $process | Wait-Process
    }

    Switch ( $Process.ExitCode ) {
      60004 {  
        Write-Verbose "Integration services already installed and are current."
      }
    }
    
    Write-Verbose "  ExitCode : $($process.ExitCode)"
    return $process.ExitCode

  } 
  else {
    throw "Setup executable ($Setup) not found"
  }
}


# vim:sw=2:ts=2:et:foldexpr=getline(v\:lnum)=~'^\s*$'&&getline(v\:lnum-1)=~'^\s*$'&&getline(v\:lnum+1)=~'\S'?'<1'\:1:fdm=expr:filetype=ps1:ff=dos:fenc=ASCII

