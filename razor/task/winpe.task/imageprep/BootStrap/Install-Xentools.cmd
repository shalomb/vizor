@echo on

set THISDIR=%~dp0
PATH=%PATH%;%THISDIR%;%THISDIR%\..

call Invoke-ImagePrep.cmd Install-Xentools

if "%errorlevel%"=="0" (
  echo. Install-XenTools complete, restarting ..
  shutdown -r -f -t 120   
)
