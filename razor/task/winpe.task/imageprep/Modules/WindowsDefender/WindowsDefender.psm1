# Script Module WindowsDefender/WindowsDefender.psm1

Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0


$WinDefendDir   = Join-Path $Env:ProgramFiles 'Windows Defender'
$WinDefendPath  = Join-Path $WinDefendDir     'MpCmdRun.exe'

function Test-IsWindowsDefenderAvailable {
  [CmdletBinding()] Param()
  Test-Path $WinDefendPath
}

function Disable-WindowsDefender {
  [CmdletBinding()]
  Param()
  Get-Service -Name WinDefend | Set-Service -StartupType Disabled -PassThru | Stop-Service -Verbose:$VerbosePreference
}


function Enable-WindowsDefender {
  [CmdletBinding()]
  Param()
  Get-Service -Name WinDefend | Set-Service -StartupType Manual -PassThru | Restart-Service -Verbose:$VerbosePreference
}


function Invoke-WindowsDefenderCommand {
  [CmdletBinding()]
  Param(
    [Switch]$GetFiles,
    [Switch]$EnableIntegrityServices,
    [String[]]$MPCmdRunArgs
  )

  $WinDefendArgs  = @()
  $WinDefendArgs =    if ($GetFiles)                { '-Getfiles' }
                  elseif ($EnableIntegrityServices) { '-EnableIntegrityServices' }
                  elseif ($MPCmdRunArgs)            { $MPCmdRunArgs }

  Write-Verbose "$WinDefendPath $WinDefendArgs"

  $process = Start-Process -FilePath $WinDefendPath -ArgumentList $WinDefendArgs -PassThru -Wait -NoNewWindow
  if ( -not( $Process ) ) {
    throw "Error executing $WinDefendPath $WinDefendArgs"
  }
  else {
    $Process | Select *path*,*id,*name,*title* | %{ Write-Verbose "  $_" }
    Write-Verbose "  Waiting for process to end"
    $process | Wait-Process
  }

  Write-Verbose "  ExitCode : $($Process.ExitCode)"
  return $Process.ExitCode
}


function Invoke-WindowsDefenderUpdate {
  [CmdletBinding()]
  Param()
  
  $WinDefendArgs  = @( '-SignatureUpdate' )
  Write-Verbose "$WinDefendPath $WinDefendArgs"

  $process = Start-Process -FilePath $WinDefendPath -ArgumentList $WinDefendArgs -PassThru -Wait -NoNewWindow
  if ( -not( $Process ) ) {
    throw "Error executing $WinDefendPath $WinDefendArgs"
  }
  else {
    $Process | Select *path*,*id,*name,*title* | %{ Write-Verbose "  $_" }
    Write-Verbose "  Waiting for process to end"
    $process | Wait-Process
  }

  Write-Verbose "  ExitCode : $($Process.ExitCode)"
  return $Process.ExitCode
}


function Invoke-WindowsDefenderScan {
  [CmdletBinding()]
  Param(
    [Switch]$Default = $True,
    [Switch]$Full,
    [Switch]$Quick,
    $FilePath
  )
  
  $ScanType =     if ( $Quick     ) { '-1' }
              elseif ( $Full      ) { '-2' }
              elseif ( $FilePath  ) { "-3 -File $Path" }
              elseif ( $Default   ) { '-0' }
  $WinDefendArgs  = @( '-scan', $ScanType )
  
  Write-Verbose "$WinDefendPath $WinDefendArgs  # Quick:$Quick, Full:$Full, FilePath:$FilePath, Default:$Default"
  $process = Start-Process -FilePath $WinDefendPath -ArgumentList $WinDefendArgs -wait -PassThru -NoNewWindow
  if ( -not( $Process ) ) {
    throw "Error executing $WinDefendPath $WinDefendArgs"
  }
  else {
    $Process | Wait-Process
  }

  Write-Verbose "  ExitCode : $($Process.ExitCode)"
  Switch ($Process.ExitCode) {
    0   { Write-Verbose "Scan finished successfully."; break; }
    *   { Throw "Scan returned $($Process.ExitCode), intervention required."; }
  }
  return $Process.ExitCode
}



# vim:sw=2:ts=2:et:foldexpr=getline(v\:lnum)=~'^\s*$'&&getline(v\:lnum-1)=~'^\s*$'&&getline(v\:lnum+1)=~'\S'?'<1'\:1:fdm=expr:filetype=ps1:ff=dos:fenc=ASCII

