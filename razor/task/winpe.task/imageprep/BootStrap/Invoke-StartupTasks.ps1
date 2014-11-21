[CmdletBinding()]
Param(
  [String] $StartupTasksDir,
  [Switch] $RunOnce
)

<#
.SYNOPSIS
Execute scripts in a given directory.

.DESCRIPTION
This script is invoked on machine startup or user logon via a cmd wrapper.
B

.PARAMETER StartupTasksDir
The directory to scan for executable scripts. This directory is inferred
relative to the location of this script if not specified.

.PARAMETER RunOnce
Run the fouund scripts once only - to simulate 'firstboot' mode.
#>

Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0

$VerbosePreference="CONTINUE"
$ErrorActionPreference="STOP"

$ThisScript = (Resolve-Path $MyInvocation.InvocationName).ProviderPath
$ThisDir    = ([System.IO.FileInfo]$ThisScript).Directory.FullName

Write-Host "Invoked '$ThisScript' in '$ThisDir'"

function testpath {
  [CmdletBinding()]
  Param(
    $Path
  )
  if ( $Path ) {
    if (Test-Path $Path) {
      Write-Verbose "Path exists : $Path"
      return $Path
    }
  }
  $False
}

Write-Verbose "PWD : $PWD"

if      ( testpath($StartupTasksDir)  ) {
  Write-Verbose "Using StartupTasksDir ($StartupTasksDir) specified as parameter."
} 
else {
  Write-Verbose "StartupTasksDir not specified .. attempting to autoresolve."
  if  ( testpath($StartupTasksDir = $Env:STARTUPTASKSDIR) ) {
    Write-Verbose "Using StartupTasksDir ($StartupTasksDir) specified in the STARTUPDIR environment variable."
  } 
  elseif  ( testpath($StartupTasksDir = ($StartupTasksDir = Join-Path "$($PWD.ProviderPath)" "Firstboot.d")) ) { # TODO, change
    Write-Verbose "Using StartupTasksDir ($StartupTasksDir) relative the PWD ($($PWD.ProviderPath))."
  }
  elseif  ( testpath($StartupTasksDir = ($StartupTasksDir = Join-Path $ThisDir "StartupTasks")) ) {
    Write-Verbose "Using StartupTasksDir ($StartupTasksDir) relative the script location."
  }
  else {
    Throw "StartupTasksDir could not be determined"
  }
}

if ( -not(Test-Path $StartupTasksDir) ) {
  throw "No StartupTasksDir found .. giving up."
}

# Use cmd.exe's notion of executables, see $Env:PATHEXT or %PATHEXT%
# PATHEXT=.COM;.EXE;.BAT;.CMD;.VBS;.VBE;.JS;.JSE;.WSF;.WSH;.MSC;.PSC1
$PathExt   = "ps1", "psc1", "msc", ($Env:PATHEXT -split "[;.]" | ?{$_}) | %{$_} | %{$_.ToLower()}
$PathExtRE = [Regex]("\.(?:" + ($PathExt -join "|") + ")$") # Any file whose extension/suffix matches an
                                                            # entry in $Env:PATHEXT
Write-Verbose "  Listing executables matching ~ $PathExtRE in $StartupTasksDir"
Write-Verbose ""

$Tasks = ls $StartupTasksDir | ?{
    (!$_.PSIsContainer) -and ($_ -imatch "$PathExtRE")
  } | sort FullName | %{ 
    Write-Verbose "  Script : $($_.FullName)"; 
    $_.FullName 
  }

$StateFileDir = (Join-Path $Env:PROGRAMDATA 'Citrix\StartupTasks\run') 
if (-not(Test-Path $StateFileDir)) {
  mkdir -force $StateFileDir | Out-Null
}

Write-Verbose ""
foreach ($Task in $Tasks) {

  $StateFile  = Join-Path $StateFileDir "$(Split-Path $Task -Leaf).run.xml"

  Write-Host -f cyan "`nConsidering '$Task'"
  if ( Test-Path $StateFile ) {
    try {
      $RunTaskState = Import-CliXml -Path $StateFile
      if ( $RunTaskState.ExitCode -eq 0 ) {
        Write-Verbose "  Task already run (ExitCode 0 captured $StateFile)"
        continue
      }
    } catch {}
  }

  try {
    $TaskResult = New-Object PSObject
    $TaskResult | Add-Member NoteProperty 'Task'      $Task
    $TaskResult | Add-Member NoteProperty 'User'      $Env:USERNAME
    $TaskResult | Add-Member NoteProperty 'Hostname'  $Env:COMPUTERNAME
    $TaskResult | Add-Member NoteProperty 'PWD'       $PWD.ProviderPath
    $TaskResult | Add-Member NoteProperty 'PPID'      $PID

    try {
      if ( $Task -imatch '.ps1$' ) {
        Write-Verbose "Launching as a powershell script."
        $Proc = Start-Process -FilePath 'powershell.exe' -PassThru -Wait -NoNewWindow `
                -ArgumentList "-NoLogo -NoProfile -Command $Task" `
      }
      else {
        Write-Verbose "Launching as an executable."
        $Proc = Start-Process -FilePath $Task -PassThru -Wait -NoNewWindow
      }
      if ( $Proc ) {
        $Proc.WaitForExit();
        $ExitCode = $Proc.ExitCode;
        Write-Verbose "ExitCode : $ExitCode";
        $TaskResult | Add-Member NoteProperty 'ExitCode'  $ExitCode
        $TaskResult | Add-Member NoteProperty 'PID'       $Proc.Id
        $TaskResult | Add-Member NoteProperty 'ProcessName' $Proc.Name
        $TaskResult | Add-Member NoteProperty 'StartTime' $Proc.StartTime
        $TaskResult | Add-Member NoteProperty 'ExitTime'  $Proc.ExitTime
        $TaskResult | Add-Member NoteProperty 'EnvironmentVariables' $Proc.StartInfo.EnvironmentVariables
        if ( $ExitCode -eq 0 ) {
          $TaskResult | Export-CliXml -Path $StateFile
        }
        $RunFile = Join-Path $StateFileDir "$([String](Split-Path $StateFile -Leaf) -replace '.run.xml').$(Get-Date -UFormat '%s').attempt.xml"
        $TaskResult | Export-CliXml -Path $RunFile
        Write-Output $TaskResult
      }
      else {
        Throw "Failed to launch process for task '$task' : $_"
      }
    }
    catch [Exception] {
      throw "Caught $_"
    }

  } catch [Exception] {
    Write-Host -f red "`nError executing task '$Task'"
    Write-Host -f red "  $($Error[0]), $_"
  }

}

