@echo off

:: SYNOPSIS
::   Start-Bootstrap.cmd - Start the process of bootstrapping the node

if "%1"=="-disabled" (
  echo.%0 is disabled .. exiting.
  goto END
)

set THISDIR=%~dp0
PATH=%PATH%;%THISDIR%

set BootstrapScript=%THISDIR%\%~n0.ps1

echo.
echo.Forcing a w32time resync ...
echo.
powershell -noninteractive -nologo -noprofile -command "sc.exe config W32Time start= auto | Write-Verbose -Verbose"
powershell -noninteractive -nologo -noprofile -command "Get-Service w32time | Start-Service -Verbose; Start-Sleep 2"
:: powershell -noninteractive -nologo -noprofile -command "gwmi Win32_NetworkAdapterConfiguration | ?{ $_.DNSDomain } | ForEach{ $d=$_.DNSDomain; & NET.EXE TIME /DOMAIN:$d /SET /YES | Write-Verbose -Verbose }"
powershell -noninteractive -nologo -noprofile -command "w32tm.exe /resync /rediscover /nowait | Write-Verbose -Verbose"

echo.
echo.Starting bootstrap ...
echo.
powershell -noninteractive -nologo -noprofile -executionpolicy bypass -command "%BootstrapScript%"

set bootstrap_errorlevel=%errorlevel%

if %bootstrap_errorlevel% NEQ 0 goto BOOTSTRAP_FAILED

goto END

:BOOTSTRAP_FAILED
echo.
echo.An error occurred executing %0. Bootstrap failed.
echo. %BootstrapScript% returned a non-zero exit code: %bootstrap_errorlevel%
echo.
powershell -noninteractive -nologo -noprofile -command 'sleep 0xFFFF'

:END
exit /b %BootstrapScript%

