@echo off

:: SYNOPSIS
::   BootStrap-PowerShell-2.0.cmd

:: DESCRIPTION
::   This script satisfies the PowerShell 2.0 and Windows Update 
::   prerequisites in order to then bootstrap the PowerShell 
::   ImagePrep scripts.
::
::   These depencencies include
::      * Robocopy (for XP)
::      * Hotfix KB898461 (for XP)
::      * .NET Framework 2.0 SP2 (Currently Skipped)
::      * .NET Framework 3.5 SP1
::      * PowerShell
::
::   It currently installs the .NET Framework on the following 
::   windows versions
::      * Windows 5.1 - XP (not 2003)
::      * Windows 6.0 - Vista
::      * Windows 6.1 - Windows 7 and Windows 2008 R2 Server
::      * Windows 6.2 - Windows 8 and Windows 2012 Server
::     

:: LINKS
::  Original Script, Heavily modified version of
::    http://adamstech.wordpress.com/2010/11/11/install-powershell-2-0-on-windows-xp-using-a-batch-file/
::
::  Detecting .NET Framework Versions
::    http://support.microsoft.com/kb/318785

:: TODO
::  * Make this modular instead of using gotos/calls like is done currently
::    * This is required to allow users to override the logic and force installs
::    * Expose the functions in a way that is callable from the cmdline
::  * Make this portable so that paths are not hardcoded
::    * We might have another .cmd file that simply has the installer paths defined


:: if "%ERRORLEVEL%"=="0" goto show_powershell_version
echo.

@echo off
:: Define the locations of the software packages and the flags they take for an unattended install
::  * Include where possible, flags that show progress as these tasks take considerable time to complete
set   dotnetfx_20sp2_x86_install_cmd=\\camautonfs01.eng.citrite.net\software\Microsoft\dotNet\2.0\NetFx20SP2_x86.exe                          /passive /norestart
set   dotnetfx_20sp2_x64_install_cmd=\\camautonfs01.eng.citrite.net\software\Microsoft\dotNet\2.0\NetFx20SP2_x64.exe                          /passive /norestart
set   dotnetfx_35sp1_x86_install_cmd=\\camautonfs01.eng.citrite.net\software\Microsoft\dotNet\3.5\sp1\dotnetfx35.exe                          /passive /norestart
set   dotnetfx_35sp1_x64_install_cmd=\\camautonfs01.eng.citrite.net\software\Microsoft\dotNet\3.5\sp1\dotnetfx35.exe                          /passive /norestart
set    powershell_xp_x86_install_cmd=\\camautonfs01.eng.citrite.net\software\Microsoft\PowerShell\XP\WindowsXP-KB968930-x86-ENG.exe           /passive /norestart
set    powershell_xp_x64_install_cmd=\\camautonfs01.eng.citrite.net\software\Microsoft\PowerShell\XP\WindowsXP-KB968930-x64-ENG.exe           /passive /norestart
set  powershell_2003_x64_install_cmd=\\camautonfs01.eng.citrite.net\software\Microsoft\PowerShell\W2K3\WindowsServer2003-KB968930-x64-ENG.exe /passive /norestart
set powershell_vista_x86_install_cmd=wusa.exe \\camautonfs01.eng.citrite.net\software\Microsoft\PowerShell\Vista\Windows6.0-KB968930-x86.msu  /quiet   /norestart
:: Package Installer for Windows - Needed by WindowsUpdate.psm1
::   http://support.microsoft.com/kb/898461
set         KB898461_x86_install_cmd=\\camautonfs01.eng.citrite.net\automation\software\Microsoft\Package_Installer_For_WindowsUpdate\WindowsXP-KB898461-x86-ENU.exe  /passive /norestart
set         KB898461_x64_install_cmd=\\camautonfs01.eng.citrite.net\automation\software\Microsoft\Package_Installer_For_WindowsUpdate\WindowsXP-KB898461-x86-ENU.exe  /passive /norestart
:: Robocopy for XP
set                     robocopy_exe=\\camautonfs01.eng.citrite.net\software\Microsoft\SysInternals\robocopy.exe


ver.exe | find.exe /i "5.1." >NUL
if %errorlevel%==0 set os_is_xp_or_2003=1

ver.exe | find.exe /i "5.2." >NUL
if %errorlevel%==0      set os_is_2003=1
if "%os_is_2003%"=="1"  set os_is_xp_or_2003=1
if "%os_is_xp_or_2003%"=="1"    goto BEGIN_XP_2003

ver.exe | find.exe /i "6.0." >NUL
if %errorlevel%==0 set os_is_vista=1
if "%os_is_vista%"=="1" goto BEGIN

ver.exe | find.exe /i "6.1." >NUL
:: 2008 needs the role enabled
if "%errorlevel%"=="0" set os_is_win7_or_2008=1
if "%os_is_win7_or_2008%"=="1" goto test_dotnet_35_sp1

:: Default
goto show_powershell_version


:BEGIN_XP_2003
echo BEGIN_XP_2003      - Prerequisites for XP/2003
reg.exe query "HKLM\SOFTWARE\Microsoft\Updates\Windows XP\SP3\KB898461" /v Description | find /i "KB898461" >NUL
if "%ERRORLEVEL%"=="0" (
  echo.    HotFix KB898461 Installed : 1
  goto test_install_robocopy
)

echo Installing KB898461 - Permanent Copy of the Package Installer for Windows Update
if %PROCESSOR_ARCHITECTURE% EQU x86 (
  start "Invoking '%KB898461_x86_install_cmd%'" /wait %KB898461_x86_install_cmd%
)
if %PROCESSOR_ARCHITECTURE% EQU AMD64 (
  start "Invoking '%KB898461_x64_install_cmd%'" /wait %KB898461_x64_install_cmd%
)

:test_install_robocopy
echo test_install_robocopy - Install Robocopy for XP/2003
if exist %WinDir%\System32\robocopy.exe (
  echo.    robocopy installed : 1
)
if not exist %WinDir%\System32\robocopy.exe (
  copy /v /y %robocopy_exe% %WinDir%\System32\
)

:BEGIN


:: goto test_dotnet_35_sp1
:: skip test_dotnet_20_sp2 - it seems unnecessary as .Net3.5SP1 seems to 
:: satisfy the .Net dependency for powershell 2.0. Go straight to 
:: test_dotnet_35_sp1 instead.

:test_dotnet_20_sp2
echo test_dotnet_20_sp2 - .NET Framework 2.0 SP1
for /f "tokens=3" %%A IN ('reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v2.0.50727" /v SP ^| find "SP"')  do set NetFramework20sp1=%%A
echo.    .NET Framework 2.0 Service Pack version detected : %NetFramework20sp1%
if not "%NetFramework20sp1%"=="" goto test_dotnet_35_sp1

echo.    Installing .NET Framework 2.0 SP1 (%PROCESSOR_ARCHITECTURE%) ...
if %PROCESSOR_ARCHITECTURE% EQU x86 (
  start "Invoking '%dotnetfx_20sp2_x86_install_cmd%'" /wait %dotnetfx_20sp2_x86_install_cmd%
)
echo exit_code: %errorlevel%
if %PROCESSOR_ARCHITECTURE% EQU AMD64 (
  start "Invoking '%dotnetfx_20sp2_x64_install_cmd%'" /wait %dotnetfx_20sp2_x64_install_cmd%
)
echo exit_code: %errorlevel%

exit /b 3
goto test_dotnet_35_sp1


:test_dotnet_35_sp1
echo test_dotnet_35_sp1 - .NET Framework 3.5 SP1
for /f "tokens=3" %%A IN ('reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5" /v SP ^| find "SP"') do set NetFramework35sp1=%%A
echo.    .NET Framework 3.5 Service Pack version detected : %NetFramework35sp1%
if not "%NetFramework35sp1%"==""    goto test_powershell_20

if "%os_is_win7_or_2008%"=="1" (
  echo.    Enabling NetFx3 Role ...
  start "" /wait ocsetup.exe NetFx3
  goto show_powershell_version
)

echo.    Installing .Net Framework 3.5 SP1 (%PROCESSOR_ARCHITECTURE%) ...
if %PROCESSOR_ARCHITECTURE% EQU x86 (
  start "Invoking '%dotnetfx_35sp1_x86_install_cmd%'" /wait %dotnetfx_35sp1_x86_install_cmd%
)
echo exit_code: %errorlevel%
goto test_powershell_20
if %PROCESSOR_ARCHITECTURE% EQU AMD64 (
  start "Invoking '%dotnetfx_35sp1_x64_install_cmd%'" /wait %dotnetfx_35sp1_x64_install_cmd%
)
echo exit_code: %errorlevel%
goto test_powershell_20


:test_powershell_20
echo test_powershell_20 - Powershell 2.0
for /f "tokens=3" %%A IN ('reg query "HKLM\SOFTWARE\Microsoft\PowerShell\1" /v Install ^| find "Install"') do set PowerShellInstalled=%%A
echo.    PowerShell Installed : %PowerShellInstalled%
if not "%PowerShellInstalled%"=="" goto show_powershell_version

if "%os_is_2003%"=="1"        goto install_powershell_20_2003
if "%os_is_xp_or_2003%"=="1"  goto install_powershell_20_xp
if "%os_is_vista%"=="1"       goto install_powershell_20_vista

:: BUG/TODO : PowerShell for 2003 is not satisfied below
:: require a better mechanism for differentiating XP from 2003.

:install_powershell_20_2003
if %PROCESSOR_ARCHITECTURE% EQU AMD64 (
  start "Invoking '%powershell_2003_x64_install_cmd%'" /wait %powershell_2003_x64_install_cmd%
)
set install_powershell_20_2003_status=%errorlevel%
echo exit_code: %install_powershell_20_2003_status%
goto show_powershell_version

:install_powershell_20_xp
echo. install_powershell_20_xp  -  Installing PowerShell 2.0 (%PROCESSOR_ARCHITECTURE%) for xp ...
if %PROCESSOR_ARCHITECTURE% EQU x86 (
  start "Invoking '%powershell_xp_x86_install_cmd%'" /wait %powershell_xp_x86_install_cmd%
)
set install_powershell_20_xp_status=%errorlevel%
echo exit_code: %install_powershell_20_xp_status%
goto show_powershell_version

if %PROCESSOR_ARCHITECTURE% EQU AMD64 (
  start "Invoking '%powershell_xp_x64_install_cmd%'" /wait %powershell_xp_x64_install_cmd%
)
set install_powershell_20_xp_status=%errorlevel%
echo exit_code: %install_powershell_20_xp_status%
goto show_powershell_version


:install_powershell_20_vista
echo.    Installing PowerShell 2.0 (%PROCESSOR_ARCHITECTURE%) for Vista ...
if %PROCESSOR_ARCHITECTURE% EQU x86 (
  start "Invoking '%powershell_vista_x86_install_cmd%'" /wait %powershell_vista_x86_install_cmd%
)
set install_powershell_20_vista_status=%errorlevel%
echo exit_code: %install_powershell_20_vista_status%
goto show_powershell_version

if %PROCESSOR_ARCHITECTURE% EQU AMD64 (
  start "Invoking '%powershell_vista_x64_install_cmd%'" /wait %powershell_vista_x64_install_cmd%
)
echo exit_code: %errorlevel%
goto show_powershell_version


:show_powershell_version
echo.show_powershell_version - Display PowerShell version.
:: we need to fully resolve powershell.exe as the shell instance
:: that started this script will not have hashed its location.
%windir%\System32\WindowsPowerShell\v1.0\powershell.exe -command "Write-Host \"    $($PSHOME): Version ($($PSVersionTable.PSVersion))\" -Verbose; exit 0"
set test_powershell_version_status=%errorlevel%
if "%test_powershell_version_status%" NEQ "0" (
  echo An error occured executing powershell to validate its installation.
)

exit /b %test_powershell_version_status%

:EOF


:: We've falled down some unexpected path and not completed the mission
:: so fail abnormally.
exit /b 3
