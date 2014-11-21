# Script Module WindowsDefender/WindowsDefender.psm1

Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0


$WinMgmtPath = (@(gcm winmgmt.exe | %{ $_.Definition } ))[0]


function Invoke-WinMGMT {
  [CmdletBinding()]
  Param(
    [Switch]$VerifyRepository = $True,
    [Switch]$ResetRepository,
    [Switch]$SalvageRepository,
    [Switch]$ResyncPerf,
    [String]$VerifyRepositoryPath,
    [String[]]$WinMgmtArgs
  )

  $WinMgmtArgs  = @()
  $WinMgmtArgs =      if ( $VerifyRepositoryPath  ) { "/VerifyRepository $VerifyRepository" }
                  elseif ( $ResetRepository       ) { '/ResetRepository' }
                  elseif ( $SalvageRepository     ) { '/SalvageRepository' }
                  elseif ( $ResyncPerf            ) { '/ResyncPerf' }
                  elseif ( $WinMgmtArgs           ) { '/ResyncPerf' }
                  elseif ( $VerifyRepository      ) { '/VerifyRepository' }

  Write-Verbose "$WinMgmtPath $WinMgmtArgs"

  $process = Start-Process -FilePath $WinMgmtPath -ArgumentList $WinMgmtArgs -PassThru -Wait -NoNewWindow
  if ( -not( $Process ) ) {
    throw "Error executing $WinMgmtPath $WinMgmtArgs"
  }
  else {
    $Process | Select *path*,*id,*name,*title* | %{ Write-Verbose "  $_" }
    Write-Verbose "  Waiting for process to end"
    $process | Wait-Process
  }

  Write-Verbose "  ExitCode : $($Process.ExitCode)"
  return $Process.ExitCode

}



# vim:sw=2:ts=2:et:foldexpr=getline(v\:lnum)=~'^\s*$'&&getline(v\:lnum-1)=~'^\s*$'&&getline(v\:lnum+1)=~'\S'?'<1'\:1:fdm=expr:filetype=ps1:ff=dos:fenc=ASCII

