# Powershell Script VMGuestTools/Tests/Install-VMGuestTools.ps1

<#
.SYNOPSIS
Script to install Guest Tools/PV Drivers for Guest Virtual Machines.

.DESCRIPTION
Install the Guest Tools for Guest Virtual Machines on XenServer, Hyper-V and VMWare.
#>

[CmdletBinding()]
Param(
  [Alias("Install")]
    [Switch]$SelfInstall,
  [ValidateSet(1,2)] 
    [Int32]$TraceLevel = 0
)


Set-StrictMode  -Version  2.0         # Support OS <= Win7
Set-PSDebug     -Trace    $TraceLevel # Set to {1,2} for tracing
# $ErrorActionPreference  = 'INQUIRE'

$ThisScript     = $MyInvocation.MyCommand.path
$ThisScriptName = Split-Path  $ThisScript -leaf
$ThisDir        = Split-Path  ($MyInvocation.MyCommand.path) -Parent
$ThisModuleDir  = Split-Path  $ThisDir        -Parent
$ModulesDir     = Split-Path  $ThisModuleDir  -Parent
$Env:PSModulePath = "$ModulesDir;${Env:PSModulePath}"


Import-Module ModuleUtils
Import-Module VMGuestTools
Import-Module CDRom
Import-Module XenTools
Import-Module VMWareTools
Import-Module HyperVIC

function Install-Self {
  [CmdletBinding()]
  Param()

# Generate a .cmd file to get around the default execution policy restrictions
# Powershell is invoked with the execution policy temporarily set to bypass
# The default is restored upon process completion.
$Script = @"
@echo off
set THISDIR=%~dp0
set WRAPPEDCMD=%THISDIR%\${ThisScriptName}

cd %THISDIR%
if exist %WRAPPEDCMD% (
  powershell.exe -nologo -noprofile -executionpolicy bypass -command %WRAPPEDCMD%
)
if not exist %WRAPPEDCMD% ( del /f /q %WRAPPEDCMD%  ) 
"@

  $LogonScript = (Join-Path $ThisDir "${ThisScriptName}.cmd")
  $Script | Out-File -Encoding ASCII $LogonScript

  SystemUtils\Install-MachineStartupScript `
    -ScriptPath $LogonScript -Verbose:$VerbosePreference

<#
.SYNOPSIS
Install the VMGuestTools installer script (this script) as a global logon script
.DESCRIPTION
Install the VMGuestTools installer script (this script) as a global logon script
such that it is invoked on user (administrator) logon.
#>
}


Write-Host -Fore Cyan "`nVM GuestTools installer.`n"


If ($SelfInstall) {
  Write-Host "Installing '$ThisScriptName' as a logon script ... "
  Install-Self -Verbose:$VerbosePreference
  exit $?
}
  

$InstallStatus = $False

try {
  Write-Host "Checking VM Guest Tools install status ... "
  $InstallStatus = (Get-VMGuestToolsStatus).Installed
  Write-Host -Fore Cyan " InstallStatus : $InstallStatus"
  sleep 0.5
} 
catch {
  ;
}
finally {
  Write-Host "  InstallStatus : $InstallStatus"
  Write-Host ""
}


if ( $InstallStatus ) {
  Write-Host -Fore Cyan "VM Guest Tools already installed. $($InstallStatus)"
  # TODO : deregistering this startup script by removing it is not ideal.
  rm -Verbose -Force $ThisScript
} 
else {

  function Show-WMIInfo {
    [CmdletBinding()]
    Param(
      [String]$WMIClass,
      [Regex]$Filter
    )
    Write-Host -Fore Cyan ($WMIClass -replace 'Win32_')
    try {
      $gwmi = @(Gwmi $WMIClass);
      $keys = $gwmi[0] | gm | ?{ $_.MemberType -eq "Property" } | ?{ 
        $_.Name -inotlike "_*" 
      } | ?{
        $_.Name -imatch $Filter
      } | %{ $_.Name }
      $gwmi | %{
        $this = $_
        $keys | %{
          "    {0,-18} : {1}" -f $_, $this.($_)
        }
      }
    } catch {
      Throw "$_"
    }
    ""
  }

  Write-Host -Fore Cyan "Host"
    "    {0,-18} : {1}" -f "Host",    $ENV:COMPUTERNAME
    "    {0,-18} : {1}" -f "Script",  $ThisScript
    "    {0,-18} : {1}" -f "Date",    "$(date -UFormat %s) ($(Get-Date))"
    ""
  # Show-WMIInfo Win32_OperatingSystem  '(^Manufacturer|^Version|^Build|OS(Type|Arch)|BootupTime|InstallDate)'
  # Show-WMIInfo Win32_ComputerSystem   '(Manufacturer|Model|^Version|SMBIOS|^Status|^SystemType|^Bootup|Hyper)'
  # Show-WMIInfo Win32_SystemEnclosure  '(Manufacturer|Model|AssetTag$)'
  Show-WMIInfo Win32_Bios             '(Manufacturer|Model|^Primary|^Version|SMBIOS)'
  Show-WMIInfo Win32_CDROMDrive       '(^Name|^Volume|^DeviceID)'

  try {
    if (Install-VMGuestTools -Verbose) {
      Dismount-CDROMDevice -Verbose # Fallback for when the install doesn't eject.
    }
    else {
      Write-Warning "VMGuestTools did not install successfully"
      sleep 0x20C49B # Max
    }
  }
  catch {
    $ErrMsg = "Install-VMGuestTools failed : $_"
    Write-Warning $ErrMsg
    sleep 0xC49B # Max
    Throw $ErrMsg
  }
}


