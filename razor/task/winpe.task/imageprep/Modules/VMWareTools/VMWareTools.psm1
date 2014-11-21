# Script Module VMWareTools/VMWareTools.psm1


Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0


function Test-IsVMWareVM {
  [CmdletBinding()]
  Param()
  (Gwmi Win32_BIOS).SerialNumber -imatch 'VMWare'
}


function Assert-IsVMWareVM {
  [CmdletBinding()]
  Param(
    [Switch]$NoThrow
  )
  if ( -not(Test-IsVMWareVM) ) {
    $ErrMsg  = "Not a VMWare VM."
    if ( $NoThrow ) {
      Write-Warning $ErrMsg
    } else {
      Throw $ErrMsg
    }
  }
  return $True
}


function Install-VMWareTools {
  [CmdletBinding()]
  Param()


  if ($CDRomDevice = Get-CDRomDevice -VolumeLabelFilter 'VMware Tools') {
    ;
  } 
  else {
    Throw "Unsupported Tools CD"
  }

  $Setup = if ( (Gwmi Win32_OperatingSystem).OSArchitecture -eq '64-bit') {
    'setup64.exe'
  } 
  elseif ( (Gwmi Win32_OperatingSystem).OSArchitecture -eq '32-bit') {
    'setup.exe'
  } 
  else { throw "OS Architecture not known." }


  if (Test-Path ($Setup = Join-Path $CDRomDevice.RootDirectory $Setup) ) {
    $SetupArgs = @( '/S', '/v', '/qn', 'REBOOT=ReallySuppress', 'REINSTALLMODE=vomus', 'REINSTALL=ALL' )

    Write-Verbose "Invoking '$Setup' $SetupArgs"
    $process = Start-Process -FilePath $Setup -wait -PassThru -ArgumentList $SetupArgs

    if (-not $process){
      throw "Error executing '$XenSetup' $XenSetupArgs"
    } else {
      $process | Wait-Process
    }

    Write-Verbose "  ExitCode : $($process.ExitCode)"
    Write-Output $process.ExitCode

  }
  else {
    throw "Install mode not supported or no setup.exe found on $CDRomDevice"
  }
  
  # Legacy
  # setup.exe /S /v /qn REBOOT=ReallySuppress REINSTALLMODE=vomus REINSTALL=ALL
  #
  # Install
  # msiexec -i "C:\Temp\VMware Tools.msi" ADDLOCAL=ALL REMOVE=Hgfs /qn
  #
  # msiexec /i "VMware Tools.msi" ADDLOCAL=ALL REMOVE="Hgfs,WYSE,GuestSDK,vmdesched" /qn /l* C:\temp\toolsinst.log /norestart
  #
  # msiexec /i "VMware Tools64.msi" ADDLOCAL=ALL REMOVE="Hgfs,WYSE,GuestSDK,vmdesched" /qn /l* C:\temp\toolsinst.log /norestart
  #
  #
  # Upgrade
  # msiexec /i "VMware Tools.msi" REINSTALL=ALL REINSTALLMODE=vomus /l*
  # C:\temp\toolsinst.log /qn /norestart
  #
  # Modify
  # msiexec /i "VMware Tools.msi" REMOVE="Hgfs" /l* C:\temp\toolsinst.log /qn
  # /norestart
}


# vim:sw=2:ts=2:et:foldexpr=getline(v\:lnum)=~'^\s*$'&&getline(v\:lnum-1)=~'^\s*$'&&getline(v\:lnum+1)=~'\S'?'<1'\:1:fdm=expr:filetype=ps1:ff=dos:fenc=ASCII

