@echo off

:: SYNOPSIS
::    StartupTasks.cmd v1.4
::    Command script to be invoked upon administrative user logon.
::
:: DESCRIPTION
::    * Launches the ASF Discovery Client in order to discover a multicast 
::      bootstrap server that will service the bootstrapping of this SUT.
::
:: COPYRIGHT
::    Copyright (c) 2011 UK Test Automation, Citrix Systems UK Ltd.
::
:: TODO
::    * Consider moving the remoting agent detection logic into the 
::      bootstrap payload delivered by the bootstrap server.
::

set THISDIR=%~dp0
PATH=%PATH%;%THISDIR%

set BootstrapScript="%THISDIR%\Start-AsyncAsfDiscovery.ps1" 
set AgentDir="%PROGRAMFILES%\Jonas"

:: TODO: This section ought to be moved out into
:: the script that actually does the installation.
:: We need to support any remoting agent
echo.
echo.Checking if a Remoting Agent is installed
echo.
IF EXIST %AgentDir% (
  echo.  Remoting agent FOUND at %AgentDir%
  goto END 2>nul
) else (
  echo.  Remoting agent NOT FOUND ..
)

echo.
echo.Starting bootstrap discovery ...
echo.
powershell -nologo -noprofile -executionpolicy remotesigned -command %BootstrapScript% 

set discovery_errorlevel=%errorlevel%

if %discovery_errorlevel% NEQ 0 goto BOOTSTRAP_FAILED

goto END

:BOOTSTRAP_FAILED
echo.
echo.An error occurred executing %0. Bootstrap failed.
echo. %BootstrapScript% returned a non-zero exit code: %discovery_errorlevel%
echo.
powershell -nologo -noprofile -command 'sleep 2147483'

:END
exit /b %BootstrapScript%

