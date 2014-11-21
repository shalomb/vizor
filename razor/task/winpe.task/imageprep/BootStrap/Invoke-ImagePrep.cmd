@echo off

setlocal enabledelayedexpansion

if "%1"=="force" (
  goto BEGIN
)

:TestIsShellElevated
>nul 2>&1 "!SYSTEMROOT!\System32\cacls.exe" "!SYSTEMROOT!\System32\Config\SYSTEM"
if "!errorlevel!" NEQ "0" (
  echo.
  echo. ERROR. The current process for user '!USERNAME!' is not elevated.
  echo.
  echo. Please invoke this script from an elevated instance.
  echo.   e.g.  runas /user:Administrator %0
  echo.
  echo. Aborting ...
  echo.
  exit /b 3
)

:BEGIN
set PATH=!PATH!;%~dp0\
set IPBASEDIR=%~dp0\..
set PSModulePath=!IPBASEDIR!\Modules;!PSModulePath!;

:TestIsPowerShellInstalled
:: BootStrap PowerShell if it isn't installed.
set PoSHDir=!windir!\System32\WindowsPowerShell\v1.0
!PoSHDir!\powershell.exe -noprofile -command "exit 0" 2>NUL
if "!errorlevel!" NEQ "0" (
  call Bootstrap-PowerShell-2.0.cmd
)

:: powershell.exe needs to be fully qualified for those cases where powershell
:: is not resolved on XP/Vista when powershell was just installed i.e. this script
:: was invoked via Bootstrap-PowerShell-2.0.cmd that installed powershell.
:CallImagePrepPS1

  :: !PoSHDir!\powershell.exe -executionpolicy bypass -noprofile -command " & (Join-Path $Env:IPBASEDIR 'BootStrap\ImagePrep.ps1') -IPBaseDir $Env:IPBASEDIR "
if "%1"=="force" ( shift )


@echo.Set-PSDebug -Trace 0                               > !TEMP!\ip.ps1
@echo.Set-StrictMode -Version 2.0                       >> !TEMP!\ip.ps1
@echo.$ErrorActionPreference='STOP'                     >> !TEMP!\ip.ps1
@echo.$PSModuleAutoLoadingPreference='None'             >> !TEMP!\ip.ps1
@echo.ipmo Microsoft.PowerShell.Host -ea 0              >> !TEMP!\ip.ps1
@echo.ipmo Microsoft.PowerShell.Management -ea 0        >> !TEMP!\ip.ps1
@echo.ipmo Microsoft.PowerShell.Utility -ea 0           >> !TEMP!\ip.ps1
@echo.ipmo ImageMaintenance                             >> !TEMP!\ip.ps1
@echo.ipmo SystemUtils                                  >> !TEMP!\ip.ps1
@echo.cd $Env:IPBASEDIR                                 >> !TEMP!\ip.ps1

:: Run a command with args passed in and then exit
if "%1" NEQ "" (
  @echo.Write-Host -Fore Cyan "Executing $args"           >> !TEMP!\ip.ps1
  @echo.$cmd,$arg=$args[0],$args[1..$($args.length - 1^)] >> !TEMP!\ip.ps1
  @echo.^& $cmd @arg                                      >> !TEMP!\ip.ps1
  !PoSHDir!\powershell.exe -executionpolicy bypass -nologo -noprofile -command "!TEMP!\ip.ps1 %*"
  exit /b !errorlevel!
)

:: Drop into an interactive shell
@echo.
@echo.ImagePrep BaseDir : !IPBASEDIR!
@echo.PATH              : !PATH!
@echo.PSModulePath      : !PSModulePath!
@echo.

@echo.Write-Host 'You are now in the image maintenance shell. The following commands should get you started.'    >> !TEMP!\ip.ps1
@echo.Write-Host '  * gcm -Mod ImageMaintenance   -  List the ImageMaintenance cmdlets.'                         >> !TEMP!\ip.ps1
@echo.Write-Host '  * Get-Task                    -  List available image maintenance tasks.'                    >> !TEMP!\ip.ps1
@echo.Write-Host '  * Resume-ImageMaintenance     -  Resume tasks for the current stage.'                        >> !TEMP!\ip.ps1

!PoSHDir!\powershell.exe -executionpolicy bypass -nologo -noprofile -noexit -command "$PSModuleAutoLoadingPreference='None'; $ErrorActionPreference='STOP'; function prompt { Write-Host -NoNewLine -Fore DarkGray  \"`n$Env:COMPUTERNAME \"; Write-Host -NoNewLine -Fore Yellow    \"$(ImageMaintenance\Get-CurrentStage)\"; Write-Host -NoNewLine -Fore Green     \"$(Get-Date -Format yyyy-MM-ddTHH:mm:ss)\"; Write-Host -NoNewLine -Fore Gray     \"`n$\";\" \"; }; !TEMP!\ip.ps1"

:EOF

exit /b !errorlevel!

