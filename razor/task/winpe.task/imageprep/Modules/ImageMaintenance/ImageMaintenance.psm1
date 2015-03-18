# Module ImageMaintenance\ImageMaintenance.psm1
# Image Maintenance Functions

Set-StrictMode -Version 2.0
Set-PSDebug -trace 0

$ErrorActionPreference = "STOP"

$IPDir          = "$Env:PROGRAMDATA\ImagePrep"
$IPLogDir       = "$IPDir\Log"
$IPRunRegister  = "$IPDir\Runs.xml"
$CurrentSequenceFile = $Null

if ( -not(Test-Path $IPDir) )     {
  mkdir -Force $IPDir -ea 0
}
if ( -not(Test-Path $IPLogDir) )  {
  mkdir -Force $IPLogDir -ea 0
}

function Get-Run {
  [CmdletBinding()] param()

  $Runs = $Null
  try {
    if ( Test-Path $IPRunRegister ) {
      if ( $Runs = Import-Clixml -Path $IPRunRegister ) {
        return $Runs
      }
      else {
        return $Null
      }
    }
    return $Null
  } catch {
    Throw "Error reading run register '$IPRunRegister' : $_"
  }
}

function Get-CurrentSequenceFile {
  [CmdletBinding()] param()

  if ( $Runs = @(Get-Run) ) {
    return ($Runs[-1]).Sequence
  }
  $Null
}

function Get-CurrentStage {
  [CmdletBinding()] param(
    [String] $SequenceFile
  )

  if ( $Runs = @(Get-Run) ) {
    try {
      return ($Runs | ?{ $_.Sequence -imatch [Regex]::Escape($SequenceFile) } | Select -Last 1)
    } catch {}
  }

  $Null
}

function Set-Stage {
  [CmdletBinding()] Param (
    [Parameter(Mandatory=$True)] [ValidateNotNullOrEmpty()]
      [Int]    $Stage,
    [Parameter(Mandatory=$True)] [ValidateNotNullOrEmpty()]
      [String] $SequenceFile = (Get-CurrentSequenceFile)
  )

  if ( -not($SequenceFile) ) {
    throw "Current sequence file not set."
  }

  $SequenceFile = (Resolve-Path $SequenceFile).ProviderPath

  [Array] $Runs = if ( $Arr = @(Get-Run) ) { $Arr } else { @() }

  $InputObject = New-Object PSObject
  $InputObject | Add-Member NoteProperty Stage    $Stage
  $InputObject | Add-Member NoteProperty Sequence $SequenceFile
  $InputObject | Add-Member NoteProperty Date     (Get-Date -UFormat '%Y-%m-%dT%T')

  $Runs += @( $InputObject )

  $Runs | Export-Clixml -Path $IPRunRegister -Force
}

function Show-Transcript {
  [CmdletBinding()]
  Param()
  $i=0
  $Transcripts = ls $IPLogDir\ImagePrep*.log | Sort LastWriteTime
  $Transcripts | %{
    $n = " {0,2}. " -f (++$i)
    Write-Host -ForegroundColor DarkGray $n -NoNewline
    Write-Host $_ -NoNewline
    Write-Host -ForegroundColor DarkGray " ($($_.Length) $($_.Mode)) " -NoNewline
    Write-Host
  }
  Write-Host ""
  Write-Host "Which one? [$i] " -NoNewline
  $Editor = if ( gcm write.exe ) { 'write.exe' } else { 'notepad.exe' }
  $Reply = [Int](Read-Host)
  if ( -not($Reply) ) {
    & $Editor $Transcripts[-1]
  }
  else {
    & $Editor $Transcripts[$Reply-1]
  }
}

function Resume-ImageMaintenance {
  [CmdletBinding()] Param(
    $SequenceFile = $Null,
    [Switch] $Force
  )

  if ( -not($SequenceFile) -and -not($SequenceFile = Get-CurrentSequenceFile) ) {
    throw "Current sequence file could not be resolved."
  }

  if ( -not(Test-Path $SequenceFile) ) {
    throw "SequenceFile '$SequenceFile' missing or not readable."
  }

  $Stage = if ( $in = Get-CurrentStage -SequenceFile $SequenceFile ) { $in.Stage } else { 0 }
  Write-Verbose "Resuming image prep with '$SequenceFile', stage '$Stage'."

  try {
    Get-Task -SequenceFile $SequenceFile -Stage $Stage | Invoke-Task -Force:$Force | fl *
    $Stage++
    Set-Stage -SequenceFile $SequenceFile -Stage $Stage
  }
  catch { throw "Error running sequence file '$SequenceFile' : $_" }
}

function Get-Task {
  [CmdletBinding()]
  Param(
    [Parameter( Mandatory=$True, ValueFromPipeline=$True  )]
    [ValidateNotNullOrEmpty()]
      $SequenceFile,
    $Stage, # TODO : Don't cast to Int - this breaks stage "0"
    [Regex]$Filter
  )

  if ( (defined $Stage) -or $Filter ) {
    if ( $TaskCollection = Get-Task -SequenceFile $SequenceFile | ?{ $_.Stage -eq $Stage } ) {
      return ($TaskCollection | ?{ $_.Name -imatch [Regex]::Escape($Filter) })
    }
  }
  else  {

    if ( -not( Test-Path $SequenceFile ) ) {
      throw "Missing sequence file : $SequenceFile"
    }

    try {
      $SequenceList = , @(& $SequenceFile) # Explicit list conversion
    } catch {
      throw "Unable to parse SequenceFile '$SequenceFile' : $_"
    }

    Write-Verbose ""
    Write-Verbose "SequenceList ($SequenceList) parsed with $($SequenceList.Count+1) objects"
    Write-Verbose ""

    $SequenceDefinitionCount=0
    foreach ( $SequenceDefinition in $SequenceList ) { # TODO: Extra layer to deparse!! PowerShell oddity, why??
      Write-Verbose "Sequence $SequenceDefinitionCount has $($SequenceList.Count + 1) stages." # Uhh

      $StageDefinitionCount=0
      foreach ( $StageDefinition in $SequenceDefinition ) {
        Write-Verbose "  Stage  $StageDefinitionCount has $($StageDefinition.Count) tasks."

        $TaskDefinitionCount=0
        foreach ( $TaskDefinition in $StageDefinition ) {
          Write-Verbose "    Task $TaskDefinitionCount = $($TaskDefinition.Name)."

          try {
            $TaskDefinition = [HashTable]$TaskDefinition
          } catch {
            throw "Unable to cast TaskDefinition to a HashTable : $_"
          }

          $Task = New-Object -TypeName PSObject
          "name", "script" | %{ # Mandatory attributes
            $Task | Add-Member NoteProperty -Name $_ -Value $TaskDefinition[$_]
          }

          $Task | Add-Member NoteProperty -Name "stage"  -Value $StageDefinitionCount
          $Task | Add-Member NoteProperty -Name "taskno" -Value $TaskDefinitionCount

          "pre","post" | %{     # Optional attributes
            if ( $taskDefinition.keys -contains $_ ) {
              $Task | Add-Member NoteProperty -Name $_ -Value $TaskDefinition[$_]
            }
            else {
              $Task | Add-Member NoteProperty -Name $_ -Value { 1 }
            }
          }

          $TaskDefinitionCount++
          Write-Output $Task
        }
        $StageDefinitionCount++
      }
      $SequenceDefinitionCount++
    }

    Write-Verbose ""
  }
}

function Invoke-Task {
# TODO,
# * Pre,Post validation
# * Switch to fail on pre-assert, pause if failed
# * Reboot Handler, switch to no reboot after stage
# * Event log gathering to spot warnings or errors after running a task
# * Task Continuation/Avoiding repetition - state files, done??
# * Logging/Transcript
# * What-If?

  [CmdletBinding(SupportsShouldProcess=$True)]
  param(
    [Parameter(
        Position=0, Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true
      ) ]
    [Alias('TaskList')]
      [Object[]]$Tasks,
    [Parameter( Mandatory=$False, ValueFromPipeline=$False  )]
      [System.IO.DirectoryInfo]$LogDir = $IPLogDir,
    [Parameter( Mandatory=$False, ValueFromPipeline=$False  )]
      [switch]$Force,
    [Parameter( Mandatory=$False, ValueFromPipeline=$False  )]
      [switch]$NoStrict,
    [Parameter( Mandatory=$False, ValueFromPipeline=$False  )]
      [switch]$ConfirmMode,
    [Parameter( Mandatory=$False, ValueFromPipeline=$False  )]
      [switch]$DryRun
  )

  begin {
    $LastSubStatus = $True
    try { Stop-Transcript | Write-Verbose } catch {}
    $LogFile = "$IPLogDir\ImagePrep-$($Env:COMPUTERNAME)-$PID-$(Get-Date -UFormat '%Y%m%dT%H%M%S').log"

    Start-Transcript -Path $LogFile | Write-Verbose

    # Write-Host ('*'  * 80)
    # Write-Host "Invocation details."
    # Write-Host "Time                             : $(Get-Date -Uformat '%Y%m%dT%H%M%S%Z')"
    # Write-Host "PID                              : $PID"
    # Write-Host "PWD                              : $PWD"
    # Write-Host "Username                         : $Env:USERNAME@$ENV:USERDOMAIN"
    # Write-Host "Hostname                         : $Env:COMPUTERNAME"
    #
    # Write-Host '$MyInvocation'
    # $MyInvocation
    #
    # Write-Host "Environment Variables "
    # ls Env:\*       | %{ $_.Name } | sort | %{ try { "{0,-32} : {1}" -f $_, (ls Env:\$_).Value } catch {} }
    #
    # Write-Host "  PS Variables "
    # ls Variable:\*  | %{ $_.Name } | sort | %{ try { "{0,-32} : {1}" -f $_, (ls Variable:\$_).Value } catch {} }
    #
    # Write-Host ""
    # Write-Host ('*'  * 80)

    Write-Verbose "Start invoking commands."
  }

  process {
    foreach ( $task in $Tasks ) {
      # Write-Host ('*'  * 80)
      # Write-Host -Fore DarkGray "$(Get-Date -Uformat '%Y%m%dT%H%M%S%Z') : Invoke-Task $($task.name)"
      # $_ | Out-String | Write-Host -Fore DarkGray

      $TaskName  = $Task.Name
      $TaskState = New-Object -TypeName PSObject
      $TaskState = Add-Member -InputObject $TaskState -PassThru -Force -MemberType NoteProperty -Name "task" -Value $task.Name
      $StateFile = Join-Path $IPLogDir $Task.Name

      $PrevStatus = $False
      if ( Test-Path $StateFile ) { try { $PrevStatus = cat $StateFile } catch {} }

      foreach ( $SubName in @("pre","script","post") ) {

        $SubState = New-Object -TypeName PSObject

        try {
          if ( ($PrevStatus -eq $True) -and -not( $Force ) ) {
            throw "Task already complete, skipping .."
          }

          if ( ($SubName -eq "script") -and ($LastSubStatus -eq $False) ) { # Pre Failed
            $SubState | Add-Member NoteProperty "status" $False
            Write-Warning "Pre script/assertion failed for task '$($Task.Name)' .. skipping."
          }
          else {
            if (Test-Member -InputObject $task -Name $SubName) {
              $Host.UI.RawUI.WindowTitle = $TaskName
              try {
                [String]$ScriptOutput = $task.$SubName.Invoke()
              }
              catch {
                Throw "Unable to invoke Sub '$SubName' for '$($Task.Name)' : $_"
              }
              # TODO: We ought to extract the error code of the process just Invoke()d to feed to 'status'
              $SubState = Add-Member -InputObject $SubState -PassThru -Force -MemberType NoteProperty -Name "status" -Value $?
              $SubState = Add-Member -InputObject $SubState -PassThru -Force -MemberType NoteProperty -Name "scriptoutput" -Value $($ScriptOutput)
              $LastSubStatus = $True
            }
            if ( $SubName -eq "script" ) { $LastSubStatus | Out-File -Encoding ASCII $StateFile }
          }

        }
        catch [Exception] {
          Write-Warning "  $TaskName/$SubName : $_"
          if ( $NoStrict -or ($SubName -imatch '^(?:pre|post)$') ) {
            $SubState = Add-Member -InputObject $SubState -PassThru -Force -MemberType NoteProperty -Name "status" -Value $False
            $SubState = Add-Member -InputObject $SubState -PassThru -Force -MemberType NoteProperty -Name "exception" -Value $_
            $LastSubStatus = $False
          }
          else {
            if ($_ -imatch 'Task already complete, skipping') {
              ;
            }
            else {
              $Local:ErrorActionPreference = "SilentlyContinue"
              $_ | Out-String | Write-Host -Fore Red
              $Local:ErrorActionPreference = "STOP"
              try { Stop-Transcript } catch {}
              Throw $_
            }
          }
        }
        finally {
          if (Test-Member -InputObject $task -Name $SubName) {
            $SubState | Add-Member NoteProperty "sub"     $task.$SubName
          }
          $TaskState  | Add-Member NoteProperty $SubName  $SubState
        }
      }
      $TaskState | Export-Clixml -Path $(Join-Path $IPLogDir "$($Task.Name).$(Get-Date -UFormat %s).report.xml")

      try { $TaskState.script.scriptoutput } catch {}
      Write-Output $TaskState

      if ( $ConfirmMode ) {
        $Reply = Read-Host -Prompt $(Write-Host -Fore cyan -NoNew "Accept? [Y/n] ")
        if ( -not($Reply) -or ($Reply -imatch '^Y(?:es)?$') ) {
          continue
        } else {
          Write-Host -Fore Red "Aborting ... "
          return
        }
      }
      # Write-Host ('*'  * 80)

    }
  }
  end {
    Write-Verbose "End transcript."
    # Write-Host ('*'  * 80)
    # Write-Host -Fore DarkGray "Use Show-Transcript to view recorded transcript(s)."
    try { Stop-Transcript | Out-Null } catch {}
  }
}

New-Alias -name rim -value Resume-ImageMaintenance

Export-ModuleMember -function *-* -Alias rim
