# Script Module MSRT/MSRT.psm1
# Wrapper around the Malicious Sofrware Removable Tool


Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0


$MRT      = "mrt.exe"
$MRTPath  = $Null


if (Test-Path ($MRTPath = "$Env:WINDIR\System32\mrt.exe")) {
    ;
} 
# TODO
#   gcm is slow on Win8.1/2012R2 - need a better find
# else {
#     try {
#       $MRTPath = (@(gcm $MRT | %{$_.Definition}))[0]
#     } catch { throw }
# }

function Invoke-MSRTScan {
  [CmdletBinding()]
  Param(
    [Switch]$DetectOnly = $True,
    [Switch]$Full,
    [Switch]$FullClean
  )

  $ScanType =     if ( $FullClean   ) { '-F:Y'  }
              elseif ( $Full        ) { '-F'    }
              elseif ( $DetectOnly  ) { '-N'    }

  $MRTArgs  = @( '-quiet', $ScanType )
  
  Write-Verbose "$MRTPath $MRTArgs  # FullClean: $FullClean, Full: $Full, DetectOnly: $DetectOnly"
  $process = Start-Process -FilePath $MRTPath -ArgumentList $MRTArgs `
              -PassThru -RedirectStandardError "$Env:TEMP\mrt.stderr.log"
  if ( -not( $Process ) ) {
    throw "Error executing $MRTPath $MRTArgs"
  }
  else {
    $Process | Select *path*,*id,*name,*title* | %{ Write-Verbose "  $_" }
    Write-Verbose "  Waiting for process to end"
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

