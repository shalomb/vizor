# Script Module TaskUtils/TaskUtils.psm1

Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0


function Get-ScheduledTask {                    #M:TaskUtils
  [CmdletBinding()] Param()
  & schtasks.exe /query /v /fo csv | ConvertFrom-CSV | ?{ -not ( $_.TaskName -match "TaskName" ) }
}


function Disable-ScheduledTask {                #M:TaskUtils
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)] $taskName
  )
  Write-Verbose "Disabling Scheduled Task: $taskName" 
  if ( [Double](Get-OSVersion).CurrentVersion -lt 6 ) { # schtasks on XP & 2003 doesn't support /disable
    & schtasks /delete /tn "$taskName" /f       | Write-Verbose
  } else {
    & schtasks /change /tn "$taskName" /disable | Write-Verbose
  }
}


