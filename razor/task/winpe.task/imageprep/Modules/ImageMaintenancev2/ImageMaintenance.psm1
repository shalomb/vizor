# Module ImageMaintenance\ImageMaintenance.psm1
# Image Maintenance Functions

Set-StrictMode -Version 2.0
Set-PSDebug -trace 0


$IPDir        = "$Env:SystemDrive\ImagePrep"
$IPStageFile  = "$IPDir\Stage.xml"
$IPLogDir     = "$IPDir\Log"
$IPSequenceFileRegister = "$IPDir\SequenceRegister.xml"


if ( -not(Test-Path $IPDir) )     { mkdir -Force $IPDir }
if ( -not(Test-Path $IPLogDir) )  { mkdir -Force $IPLogDir }


function Write-Log {                            #M:ImageMaintenance
  [CmdletBinding()]
  Param( [Parameter(mandatory=$True)]  $message )
  $date = Get-Date -UFormat '%Y%m%dT%H%M%S%Z'
  Write-Host -ForegroundColor cyan "$date $Env:COMPUTERNAME $logFacility : $message"
}


function Get-ImagePrepStage {                   #M:ImageMaintenance
  [CmdletBinding()]
  param(
  )
  if ( Test-Path $IPStageFile ) {
     $stage = Import-Clixml -Path $IPStageFile
  }
  else {
    $stage = 0
  }
  return $stage
}


function Show-ImagePrepTranscript {             #M:ImageMaintenance
  [CmdletBinding()]
  Param()
  $i=0
  $Transcripts = ls $IPLogDir\ImagePrep*.log
  $Transcripts | %{
    $n = " {0,2}. " -f (++$i)
    Write-Host -ForegroundColor DarkGray $n -NoNewline
    Write-Host $_ -NoNewline
    Write-Host -ForegroundColor DarkGray " ($($_.Length) $($_.Mode)) " -NoNewline
    Write-Host
  }
  Write-Host ""
  Write-Host "Which one? [$i] " -NoNewline
  $Reply = [Int](Read-Host)
  if ( -not($Reply) ) {
    & write.exe $Transcripts[-1]
  }
  else {
    & write.exe $Transcripts[$Reply-1]
  }
}


function Set-ImagePrepStage {                   #M:ImageMaintenance
  [CmdletBinding()]
  param ( [Parameter(Mandatory=$true)] [int] $stage )
  Export-Clixml -InputObject $stage -Path $IPStageFile -Force -Encoding ASCII

  $(Get-ImagePrepStage) -eq $stage
}


function Get-Task {                             #M:ImageMaintenance
  [CmdletBinding()]
  Param(
    [Parameter( Mandatory=$True, ValueFromPipeline=$True  )]
    [ValidateNotNullOrEmpty()]
      [String] $SequenceFile,
    $Stage, # No cast to Int - this breaks stage "0"
    [Regex]   $Filter
  )

  if ( (defined $Stage) -or $Filter ) {
    $TaskCollection = Get-Task -SequenceFile $SequenceFile | ?{ $_.Stage -eq $Stage }
    $TaskCollection = $TaskCollection | ?{ $_.Name -imatch $Filter }  # Convenient, $Null matches
    return $TaskCollection
  }
  else  {

    if ( -not( Test-Path $SequenceFile ) ) {
      throw "Missing sequence file : $SequenceFile"
    }

    try {
      $SequenceList = , @(& $SequenceFile) # Explicit list conversion
    } catch { 
      throw "Unable to read in SequenceFile '$SequenceFile' : $_"
    }

    $StageNumber = 0
    foreach ( $Sequence in $SequenceList ) { # TODO: Extra layer to deparse!! PowerShell quirk - why??
      Write-Verbose "Sequence : $($Sequence.GetType())"
      foreach ( $Step in $Sequence ) {
        Write-Verbose "Step : $($Step.GetType())"
        $TaskNumber = -1
        foreach ( $TaskDefinition in $Step ) {
          Write-Verbose "    TaskDefinition $TaskDefinition"

          try {
            $TaskDefinition = [HashTable]$TaskDefinition
          } catch { 
            throw "Unable to read in TaskDefinition 'TaskDefinition' as a HashTable."
          }

          $Task = New-Object -TypeName PSObject
          "Name", "Script" | %{ # Mandatory attributes
            $Task = Add-Member -InputObject $Task -PassThru -MemberType NoteProperty -Name $_ -Value $TaskDefinition[$_]
          }

          $TaskNumber++
          $Task | Add-Member NoteProperty "Stage"      $StageNumber -PassThru |
                  Add-Member NoteProperty "TaskNumber" $TaskNumber

          "Pre", "Post" | %{     # Optional attributes
            if ( $taskDefinition.keys -contains $_ ) {
              $Task = Add-Member -InputObject $Task -PassThru -MemberType NoteProperty -Name $_ -Value $TaskDefinition[$_]
            } 
            else {
              $Task = Add-Member -InputObject $Task -PassThru -MemberType NoteProperty -Name $_ -Value { 1 }
            }
          }

          Write-Output $Task
        }
        $TaskNumber=0
        $StageNumber++
      }
    }

  }
}


function New-HtmlReport {
  [CmdletBinding()]
  Param(
    [Object]$SequenceReport    
  )

 $SequenceReport | ConvertTo-Html -Head @'

<script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.4.4/jquery.min.js"></script>
<script type="text/javascript">
$(document).ready(function() {

    $("table th").css("background-color",  "#CDCDCD");
    $("table tr:even").css("background-color",  "#33CC66");
    $("table tr:odd").css("background-color",   "#33FF66");

    $("td").css("padding", "0.5em")
    $("td:contains('True')").css("background-color", "red");

})
</script>

'@

}

function Invoke-ScriptBlock {
  [CmdletBinding()] Param(
    [ScriptBlock] $ScriptBlock    
  )

  $Global:LastExitCode = $Null;
  $Result = @{}
  $job = [PowerShell]::Create().AddScript({
    [CmdletBinding()] Param( $SB, $R )
    $O = & $SB
    ($R.Exitcode, $R.Status, $R.Output) = ($LastExitCode, $?, $O)
  }).AddArgument($ScriptBlock).AddArgument($Result)

  $ASync = $Job.BeginInvoke()
  While ($Job.InvocationStateInfo.State -ne 'Running') {
    ;
  }

  $Job.EndInvoke($ASync)
  $Result
}

function Invoke-Task {                          #M:ImageMaintenance
# TODO, 
# * Event log gathering to spot warnings or errors after running a task
#   - Measure-EventLogEvents
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
    try { Stop-Transcript | Write-Verbose } catch {}
    $ImagePrepTranscript = "$IPLogDir\ImagePrep-$($Env:COMPUTERNAME)-$PID-$(Get-Date -UFormat '%Y%m%dT%H%M%S').log"
    
    Start-Transcript -Path $ImagePrepTranscript | Write-Verbose
    
    # Write-Verbose ('*'  * 80)
    # Write-Verbose "Invocation details."  
    # Write-Verbose "Time                             : $(Get-Date -Uformat '%Y%m%dT%H%M%S%Z')"
    # Write-Verbose "PID                              : $PID" 
    # Write-Verbose "PWD                              : $PWD"
    # Write-Verbose "Username                         : $Env:USERNAME@$ENV:USERDOMAIN"
    # Write-Verbose "Hostname                         : $Env:COMPUTERNAME"
    # 
    # Write-Verbose '$MyInvocation'
    # $MyInvocation | Write-Verbose
    # 
    # Write-Verbose "Environment Variables "
    # ls Env:\*       | %{ $_.Name } | sort | %{ 
    #   try { "{0,-32} : {1}" -f $_, (ls Env:\$_).Value } catch {} 
    # } | Write-Verbose
    # 
    # Write-Verbose "  PS Variables "
    # ls Variable:\*  | %{ $_.Name } | sort | %{ 
    #   try { "{0,-32} : {1}" -f $_, (ls Variable:\$_).Value } catch {} 
    # } | Write-Verbose
    # 
    # Write-Verbose ""
    # Write-Verbose ('*'  * 80)
    
    Write-Verbose "Start invoking commands."
    $LastScriptBlockStatus = $True  # Control from 'pre' to check if 'script' is allowed.
  }

  process {
    foreach ( $task in $Tasks ) {
      Write-Verbose ('*'  * 80)
      Write-Verbose "Task              : $($task.name)"

      $TaskReport = New-Object -TypeName PSObject
      $TaskReport | Add-Member NoteProperty "Task"      $task.Name  -PassThru |
                    Add-Member NoteProperty "Stage"     $task.Stage -PassThru |
                    Add-Member NoteProperty "Hostname"  ($Env:ComputerName)

      $StateFile    = Join-Path $IPLogDir "$($Task.Name).status.xml"
      $LogFileName  = "{0:D2}.{1:D2}--{2}-{3}.log.xml" -f $Task.Stage, $Task.TaskNumber, $Task.Name, $(Get-Date -UFormat '%s')
      $LogFile      = Join-Path $IPLogDir $LogFileName

      # $Script:LastExitCode = $Null
      $LastTaskInvocationStatus = $False
      if ( Test-Path $StateFile ) { 
        try { $LastTaskInvocationStatus = cat $StateFile } catch {} 
      }

      "Pre","Script","Post" | %{

        $ScriptBlockName    = $_ # ScriptBlockName = {'pre','script','post'}
        Write-Verbose "  Scriptblock     : $ScriptBlockName"

        $ScriptBlockReport  = New-Object -TypeName PSObject

        try {
          if ( ($LastTaskInvocationStatus -eq $True) -and -not( $Force ) ) { 
            # This task was already run, we skip
            throw "Task already complete, skipping .." 
          } 

          if ( ($ScriptBlockName -eq "Script") -and ($LastScriptBlockStatus -eq $False) ) { # Pre Failed
            # This is a 'script' scriptblock, we only run if the last scriptblock (i.e. 'pre')
            # successfully ran or returned a safe exit code.
            $ScriptBlockReport | Add-Member NoteProperty "Status" $False
            Write-Warning "    Scriptblock in 'pre' failed or did not return successfully. Skipping execution of 'script'."
          } 
          else {
            if (Test-Member -InputObject $task -Name $ScriptBlockName) {
              $TaskStartTime = (Get-Date -UFormat %s)    

              Write-Host -Fore Green "SB : $($Task.$ScriptBlockName)"
              $ScriptBlockOutput  = & $Task.$ScriptBlockName
              Write-Host -Fore Green "($LastExitCode, $?)"
              ($ExitCode, $Status) = ($LastExitCode, $?)
              # $LastExitCode = $Null
              Write-Verbose "    ScriptOutput  : $ScriptBlockOutput"

              $TaskEndTime = (Get-Date -UFormat %s)    

              $ScriptBlockReport | 
                Add-Member NoteProperty "Status"    $Status         -PassThru |
                Add-Member NoteProperty "ExitCode"  $Exitcode       -PassThru |
                Add-Member NoteProperty "StartTime" $TaskStartTime  -PassThru |
                Add-Member NoteProperty "EndTime"   $TaskEndTime    -PassThru |
                Add-Member NoteProperty "Output"    $($ScriptBlockOutput)
            }

            if ( $ScriptBlockName -eq "Script" ) {
              $LastScriptBlockStatus | Out-File -Encoding ASCII $StateFile
            }
            
            # Report on the state for each sub {'pre','script','post'}
            $LastScriptBlockStatus | Out-File -Encoding ASCII "$StateFile.$ScriptBlockName.status"
          }

        } 
        catch [Exception] {
          if ( $NoStrict -or ($ScriptBlockName -imatch '^(?:pre|post)$') ) {
            $ScriptBlockReport | 
              Add-Member NoteProperty "Status"    $False -PassThru |
              Add-Member NoteProperty "Exception" $_
            $LastScriptBlockStatus = $False
          } 
          else {
            if ($_ -imatch 'Task already complete, skipping') {
              ;
            } 
            else {
              $Local:ErrorActionPreference = "SilentlyContinue" 
              $_ | Out-String | Write-Host -Fore Red
              $Local:ErrorActionPreference = "STOP" 
              Stop-Transcript | Write-Verbose
              Throw $_
            }
          }
        } 
        finally {
          $ScriptBlockReport | Add-Member NoteProperty "Scriptblock" $task.$ScriptBlockName
          $TaskReport | Add-Member NoteProperty $ScriptBlockName  $ScriptBlockReport
        }
      }

      # Write the state out to a record for later inspection/control
      $TaskReport | Export-Clixml -Path $LogFile 

      # try { $TaskReport.script.ScriptBlockOutput } catch {}
      Write-Output $TaskReport

      if ( $ConfirmMode ) {
        $Reply = Read-Host -Prompt $(Write-Host -Fore cyan -NoNew "Accept? [Y/n] ")
        if ( -not($Reply) -or ($Reply -imatch '^Y(?:es)?$') ) {
          continue
        } else {
          Write-Host -Fore Red "Aborting ... "
          return
        }
      }

    }
  }

  end {
    Write-Verbose "End transcript."
    Write-Verbose ('*'  * 80)
    Write-Verbose "Use Show-ImagePrepTranscript to view recorded transcript(s)."
    try { Stop-Transcript | Write-Verbose } catch {}
  }
}


function Resume-ImageMaintenance {              #M:ImageMaintenance
  [CmdletBinding()]
  Param(
    $SequenceFile = $Null,
    [Switch]$Force
  )

  # Get sequence file
  if ( -not($SequenceFile) ) {
    if ( Test-Path $IPSequenceFileRegister ) {
      $SequenceFile = Import-CliXml $IPSequenceFileRegister
      Write-Verbose "Found $SequenceFile from $IPSequenceFileRegister"
    } 
    if ( [String]::IsNullOrEmpty($SequenceFile) -or -not(Test-Path $IPSequenceFileRegister) ) {
      throw "Sequence file not present in register '$IPSequenceFileRegister' or as an argument to -SequenceFile"
    }
  } else {
    if (Test-Path $SequenceFile) {
      $SequenceFile = (Resolve-Path $SequenceFile).ProviderPath
      $SequenceFile | Export-CliXml -Path $IPSequenceFileRegister 
    } else {
      throw "SequenceFile '$SequenceFile' missing or not readable."
    }
  }

  try {
    $Stage = if ( Test-Path( $IPStageFile ) ) { Import-CliXml $IPStageFile } 
    $Stage = if ( $Stage ) { $Stage } else { 0 }
    Write-Verbose "Resuming image prep with '$SequenceFile', stage '$Stage'."
    Get-Task -SequenceFile $SequenceFile -Stage $Stage | Invoke-Task -Force:$Force | fl *
    $Stage++
    $Stage | Export-CliXml -Path $IPStageFile
  } 
  catch { throw $_ }
}


New-Alias -name rim -value Resume-ImageMaintenance


Export-ModuleMember -function *-* -Alias rim


#  # Param()
#  # TODO parameterise these and make this modular
#
#  Switch -Regex ( $imagePrepStage = Get-ImagePrepStage ) {
#
#    0 { # Stage 0 - doesn't assume a pristine state
#
#      Write-Host "ErrorActionPreference: $ErrorActionPreference"
#      Import-Module WindowsUpdate -Verbose -ea 1
#      # TODO, StartupTasks.cmd cannot invoke stage 0 
#      # as ExecutionPolicy is remotesigned
#      # Set-ScreenResolution -Width 1024 -Height 768         
#      # FIXME, StartupTasks.cmd et al. need to be in the public share
#      # Enable-Sysprep # Disabled until we have a proper machine naming mechanism
#      # @{ 'check'={}, 'scriptblock'={ Install-DotNet35                                                                    } }
#      # @{ 'check'={}, 'scriptblock'={ Install-DotNet35                                                                    } }
#      Install-GlobalLogonScript "$ASFSupport\StartupTasks.cmd" "ASFStartupTasks"
#      cp -ea 1 -Force -Verbose "$ASFPublicShareRealPathUNC\..\SutBaseImageScripts\StartupTasks.cmd" "$ASFSupport\StartupTasks.cmd"
#
#      Try { Stop-Transcript } catch [Exception] {}
#      Start-Transcript -Path "$logDir\$Env:COMPUTERNAME-ImageMaintenance-Stage$imagePrepStage.log"
#      Write-Verbose "Performing tasks for Stage 1 ($imagePrepStage)"
#      Write-Verbose "Connecting to $ASFControllerIPCShare"
#      & net use $ASFControllerIPCShare /user:$(Join-Path $ASFControllerHost $ASFAdministrativeUser) $ASFAdministrativeUserPassword /persistent:yes
#      Try {
#        Write-Verbose "Disabling System Restore on the system drive."
#      } catch [Exception] {}
#
#      Write-Host -ForegroundColor green -NoNewline "Finished Tasks for Stage 1 .. "
#      Set-ImagePrepStage 1
#      Stop-Transcript
#
#      Write-Verbose "Tasks for Stage 0 ($imagePrepStage) Complete"
#      if (-not $Interactive) {
#        Write-Host -ForegroundColor magenta "Rebooting in 10 seconds."
#        sleep 30
#        Restart-Computer -Confirm:$False -Force
#      } 
#      else {
#        Write-Host -ForegroundColor magenta "Reboot to continue."
#        Read-Host
#      }
#
#      exit $?
#    }
#
#    1 {
#      Start-Transcript -Path "$logDir\$Env:COMPUTERNAME-ImageMaintenance-Stage$imagePrepStage.log"
#      Write-Verbose "Performing tasks for Stage 2 ($imagePrepStage)"
#      
#      Write-Host -ForegroundColor green "Finished Tasks for Stage 2 .. "
#      Set-ImagePrepStage 2
#      Stop-Transcript
#
#      Write-Verbose "Tasks for Stage 1 ($imagePrepStage) Complete"
#      if (-not $Interactive) {
#        Write-Host -ForegroundColor magenta "Shutting down machine in 10 seconds."
#        sleep 30
#        Restart-Computer -Confirm:$False -Force
#      } 
#      else {
#        Write-Host -ForegroundColor magenta "Shutdown or reboot to continue."
#        Read-Host
#      }
#
#      exit $?
#    }
#
#    . {
#      Write-Verbose "Defaulted (Stage $ImagePrepStage). Nothing to do now. Aborting .. "
#      exit 1
#    }
#
#  }
#}

Export-ModuleMember *-*  # Private Functions are not well-named

# TODO
# ----
# VM Creation Parameters
#   Hostname
#   # of CPUs
#   # of NICs
#     Mode of Nics i.e. DHCP vs Static
#   # of additional disks

# Image Preparation Tasks
#   Hostname
#   Execute Pending NGEN Tasks
#   .Net 3.5
#   Enable IPv6
#   Windows Update
#   Instantiation on AMD and Intel Hosts
#   Locale
#   Keyboard Layout
#   Set FIPS Compliance

# Notes
# http://www.vadapt.com/2011/01/review-win7-view-optimization-guide/

# TODO
#   newsid
#   parameters for mode
#     minimal
#     reset
#     full
#     default?
#   Handle CD-ROM insertion for
#     .Net3.5 on windows 8
#     Guest Tools
#   SuperFetch ?
#   NTP Sync against Citrite.net
#   Languages
# Consider a bin/ directory
# Get the ASF structure on the public share in order
# Selectively sync down scripts as needed (or don't)
#  NGEN - 32 and 64
# VMware
#  Add-PSSnapin VMware.VimAutomation.Core
#
# REFERENCES
#   List of Resources on Windows 7 Optimization for VDI
#     http://social.technet.microsoft.com/wiki/contents/articles/4495.list-of-resources-on-windows-7-optimization-for-vdi.aspx
#
# Enable IPv6 - done
# DNS/IPv6 DNS 
# DHCPv6 and DNS
# Routing and Route Advertisement
# XML RPC / REST Service - Pending Change/Inclusion from PaulD
# HostNames Names
# Preparation on AMD/Intel Platforms
# Screen Resolution
# Hostnames and UI Name Consistency
# 2vCPUs for the Server Platforms
# Remove .Net3.5 where not needed >= Win8, WS2012
# Ensure Locale
# FIPS Compliancy
#   Windows Registry Editor Version 5.00
#   [HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa]
#   "fipsalgorithmpolicy"=dword:00000001

# Disable strict host checking
# Eject ISOs from VMs
# Locales and TimeZones
#
# driverquery
#
# sfc /scannow
#
# winmgmt /verifyrepository
# winmgmt /resetrepository  
# winmgmt /salvagerepository
# winmgmt /resyncperf
# Restart-Service winmgmt -Force  
#
# Driver Query
#  driverquery /v
#  driverquery /si
#
# bcdedit.exe
# bcdedit /hypervisorsettings
#
# bcdedit /Set LoadOptions DDISABLE_INTEGRITY_CHECKS # Disable driver integ checks
# bcdedit /set nointegritychecks ON
#
# http://vb.mvps.org/tips/shellcpl.txt
#
#  Basic Detection for 2 CPUs on server platforms

# Set and Verify Driver Signing

# Disable StrictNameCheckign for SMB shares
# LanManWorkStation EnableSecuritySignature 0x0

# Set HostName and Computer Description
# Machine Attributes and UUIDs

# Administrator password no expire
# Unset User cannot change password - for sysprep
# Sysprep

# Timezones
# Locales

# User and Groups PS Module
# Trace and Assert Module

# Set and Get Hostname

# Allow/Disallow Remote Registry

# Done Set password expiry to not expire for administrative users

# Done .Net 4 - client profile ??

# Disabling the Search Indexing Feature in Windows 7
# http://windows.microsoft.com/en-GB/windows7/Optimize-Windows-7-for-better-performance

# Set MachineName according to a defined scheme




# <#
# .SYNOPSIS
#    Script executes on SUT boot, and performs the image preparation process
# 
#    Copyright (c) Citrix Systems, Inc. All Rights Reserved.
# 
# .DESCRIPTION
#    Must be present in the controller public share and temporarily replaces the
#    bootstrap.ps1 script. This executes as a child of the SUT vm startup script
#    "startup\startuptasks.cmd" progresses a scripted image maintenance process.
# 
#    Includes:
#         1. XenTools (requires XenTools.iso to be mounted)
#         2. TODO will do windows update handling
#         3.
#         4. cleans up the system - event logs, temp folders, the update scripts...
#         5. Handles reboots using simple reboot reference counting
# 
#         * re uses the ASF library that must be present on the public share:
#             \\controller\public\ASF - ASF common script library like cleanup scipts
#             \\controller\public\ASF\SysInternals - must extract pstools
#             ** Note SysInternals EULA prohibits us doing this automatically
#         * Must not install the remoting agent - Jonas
# 
#    By design this script is called by the SUTs after windows has logged in
# #>
# 
# [CmdletBinding()]
# Param(
#   [Parameter(Position=0,Mandatory=$true)] [String] $IPBaseDir,
#                                           [Switch] $Interactive
# )


# vim:sw=2:ts=2:et:foldexpr=getline(v\:lnum)=~'^\\s*$'&&getline(v\:lnum-1)=~'^\\s*$'&&getline(v\:lnum+1)=~'\\S'?'<1'\:1:fdm=expr:filetype=ps1:ff=dos:fenc=ASCII
#
