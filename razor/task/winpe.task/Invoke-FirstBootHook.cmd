@echo off

:: Called from within the image during the specialize or oobesystem passes.

:: Argument passed in is the callback to razor
arg=%1

setlocal enabledelayedexpansion

mkdir !PROGRAMDATA!\imageprep
set log_file=!PROGRAMDATA!\imageprep\firstboothook.log

@echo.!DATE! !TIME! !USERNAME!@!COMPUTERNAME! %0 - invoke %0 %* > !log_file!

pushd %~dp0

if !PROCESSOR_ARCHITECTURE! == AMD64 ( copy curl-win-x86_64.exe !windir!\System32\curl.exe )
if !PROCESSOR_ARCHITECTURE! == x86   ( copy curl-win-x86.exe    !windir!\System32\curl.exe )

@echo.!DATE! !TIME! !USERNAME!@!COMPUTERNAME! %0 - install curl >> !log_file!
curl --version >> !log_file!

cd !TEMP!
set delegate=!TEMP!\Install-FirstBootScript.cmd

set /a retry=0
:call_delegate

@echo.!DATE! !TIME! !USERNAME!@!COMPUTERNAME! %0 - try !retry! download %1 to !delegate! >> !log_file!
curl -s %1 -o !delegate!

if exist !delegate! (
  @echo.!DATE! !TIME! !USERNAME!@!COMPUTERNAME! %0 - call !delegate! %* >> !log_file!
  call !delegate! %*
  set /a exit_code=!ERRORLEVEL!
  @echo.!DATE! !TIME! !USERNAME!@!COMPUTERNAME! %0 - exit_code !exit_code! >> !log_file!
) else (
  set /a retry=retry+1
  @echo.!DATE! !TIME! !USERNAME!@!COMPUTERNAME! %0 - file does not exist, sleep !retry! >> !log_file!
  ping -n !retry! localhost >NUL 2>&1
  goto:call_delegate
)

popd

exit /b !exit_code!
