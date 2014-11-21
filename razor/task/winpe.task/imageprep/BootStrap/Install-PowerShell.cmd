@echo off

setlocal enabledelayedexpansion

set powershell_vista_x64_url=http://download.microsoft.com/download/3/C/8/3C8CF51E-1D9D-4DAA-AAEA-5C48D1CD055C/Windows6.0-KB968930-x64.msu
set powershell_vista_x86_url=http://download.microsoft.com/download/F/9/E/F9EF6ACB-2BA8-4845-9C10-85FC4A69B207/Windows6.0-KB968930-x86.msu

ver.exe | find.exe /i "6.0." >NUL
if %errorlevel%==0 set os_is_vista=1
if "%os_is_vista%"=="1" goto vista

@echo.OS is not Vista??
goto error

:vista
if exist %windir%\System32\WindowsPowerShell\v1.0\powershell.exe (
  goto:test_ps
)
if %PROCESSOR_ARCHITECTURE% EQU x86   ( call:InstallPowerShell !powershell_vista_x86_url! )
if %PROCESSOR_ARCHITECTURE% EQU AMD64 ( call:InstallPowerShell !powershell_vista_x64_url! )
call:InstallPowerShell

set /a exit_code=!ERRORLEVEL!
@echo.Installed PowerShell exit_code=!exit_code!

:test_ps
%windir%\System32\WindowsPowerShell\v1.0\powershell.exe -command "$PSHOME; $PSVersionTable | fl *; exit 0"
exit /b !ERRORLEVEL!


goto eof

:error
@echo.An error occurred.
exit /b 3

:eof
exit /b 0


:InstallPowerShell
set powershell_msu_url=%1
set powershell_msu=!TEMP!\%~nx1

:RetryInstall
if not exist !powershell_msu! (
  @echo. Downloading PowerShell for !PROCESSOR_ARCHITECTURE! !powershell_msu_url!
  start "Download !powershell_msu!" /wait /realtime bitsadmin.exe /Transfer "Download !powershell_msu!" /download !powershell_msu_url! !powershell_msu!
)

bitsadmin.exe /info "Download !powershell_msu!"

set /a c=0
if exist !powershell_msu! (
  @echo. Installing PowerShell for !PROCESSOR_ARCHITECTURE! !powershell_msu_url!
  wusa.exe !powershell_msu! /norestart
  exit /b !ERRORLEVEL!
) else (
  ping -n !c! 127.0.0.1 >NUL 2>&1
  @echo.Failed install..retrying.
  set /a c=c+1
  if "!c!"=="10" ( exit /b 5 )
  goto:RetryInstall
)
goto :eof


