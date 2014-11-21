:: cmd.ex

@echo off


:: SYNOPSIS
::  Razor bootstrap script.
::
:: DESCRIPTION
::  This script is the razor client script and is to be 'burned-in'
::  to the razor winpe image. And as such, cannot be evaluated as
::  a razor template (.erb). All values here must be hardcoded.


setlocal enabledelayedexpansion

cd !temp!

:: The values in this section are patched when the image is prepared.
set DEBUG=[%DEBUG%]
set razor_server=[%RAZOR_SERVER%]

if !DEBUG! GEQ 1  @echo on

:: If we have a 'dot-sourceable' file at the root of the drive, let's source it.
:: The address of razor_server could be set in it for e.g.
if exist \razor.cmd call \razor.cmd

set base_url=http://!razor_server!:8080/svc
set stage2_script=second-stage.cmd

@echo.
@echo.Razor WinPE Client
@echo.
@echo. Script ................... : %0
@echo. Version .................. : [%VERSION%]
@echo. Razor Server ............. : !razor_server!
@echo. Razor API EndPoint ....... : !base_url!
@echo. Processor Architecture ... : !PROCESSOR_ARCHITECTURE!
@echo. wimlib Version ........... : [%wimlib_version%]
@echo. curl-win Version ......... : [%curl_win_version%]
@echo.

@echo.Initializing network (wpeutil.exe WaitForNetwork) ...
wpeutil.exe InitializeNetwork >NUL
set exit_code_initnet=!ERRORLEVEL!

@echo.Waiting for network (wpeutil.exe WaitForNetwork) ...
wpeutil.exe WaitForNetwork >NUL 2>&1
set exit_code_initnet2=!ERRORLEVEL!

@echo.Initializing WinPE (wpeinit) ...
wpeinit.exe >NUL
set exit_code_wpeinit=!ERRORLEVEL!
@echo.

:: Support DHCP Server discovery if razor_server is not set.
:: This part is untested - and most likely will fail.
:: TODO: We do not cater for nodes with multiple NICs properly.
if "!razor_server!"=="[]" (
  for /f "tokens=1,2 delims=:" %%g in ('ipconfig /all ^| find /i "DHCP Server"') do (
    set dhcp_server=%%h
    :: strip leading/trailing white space
    if "!dhcp_server:~-1!"==" "   set dhcp_server=!dhcp_server:~0,-1!
    if "!dhcp_server:~0,1!"==" "  set dhcp_server=!dhcp_server:~1!
  ) 
  set razor_server=!dhcp_server!
)

:: Discover all MAC Addresses
if exist mac_addresses.txt del /f /q mac_addresses.txt
for /f "tokens=1,2 delims=:" %%g in ('ipconfig /all ^| find /i "Physical Address" ^| find /v /i "00-00-00-00-00-00"') do ( 
  set mac=%%h

  :: strip leading/trailing white space
  if "!mac:~-1!"==" "   set mac=!mac:~0,-1!
  if "!mac:~0,1!"==" "  set mac=!mac:~1!

  echo !mac! >> mac_addresses.txt
)

:: Generate the node's hwid. i.e. Join up mac addresses for the URL query.
:: e.g. net0=00-15-5d-12-34-56&net1=00-15-5d-12-34-57
set hwid=
set /a c=0
for /f "delims=: tokens=1,2" %%g in ('type mac_addresses.txt') do (
  set mac=%%g

  if "!mac:~-1!"==" " set mac=!mac:~0,-1!
  
  set line=net!c!=!mac!

  set /a c+=1
  set hwid=!hwid!^&!line!
)
del /f /q mac_addresses.txt

if "!hwid:~-1!"==" " set hwid=!hwid:~0,-1!
if "!hwid:~0,1!"=="&" set hwid=!hwid:~1!


:: Print some Info to aid in debugging/troubleshooting
@echo.
@echo. Script ................... : %0
@echo. Version .................. : 0.1.0
@echo.
@echo. Razor
@echo.    Razor Server .......... : !razor_server!
@echo.    Razor Server Base Url . : !base_url!
@echo.    HWID .................. : !hwid!
@echo.
@echo. Node
@echo.    Time .................. : !date!T!time!
@echo.    Hostname .............. : !computername!
@echo.    Username .............. : !username!
@echo.    Userdomain ............ : !userdomain!
@echo.
@echo. Status
@echo.    InitializeNetwork ..... : !exit_code_initnet!
@echo.    WaitForNetwork ........ : !exit_code_initnet2!
@echo.    WPEInit ............... : !exit_code_wpeinit!
@echo.

@echo.
hostname
ipconfig /all | find /i "address"
ipconfig /all | find /i "server"
@echo.

ping -n 3 127.0.0.1 >NUL 2>&1  :: sleep 3

:: Get Node ID from server
@echo.
@echo.node_id_url ............... : !base_url!/nodeid?!hwid!
@echo.

if exist nodeid.txt del /f /q nodeid.txt
curl -s -S -L -X GET "!base_url!/nodeid?!hwid!" -o nodeid.txt

for /f "tokens=1,2 delims=:,}" %%g in ('type nodeid.txt') do (
  set id=%%h
)

:: Fetch the second-stage script
set stage2_url=!base_url!/file/!id!/second-stage.cmd

@echo.stage2_url ............... : !stage2_url!

curl -s -S -L -X GET "!stage2_url!" -o !stage2_script!

:: Execute the second-stage script
if exist !stage2_script! (
  call !stage2_script!
  set exit_code=!ERRORLEVEL!
) else (
  echo.
  echo. --------------------------------------------------------------------------
  echo.# ERROR : Stage2 script '!stage2_script!' was not found or not downloaded. #
  echo. --------------------------------------------------------------------------
  echo.
  set exit_code=9009
  :: This may fail given this failure path but let's try anyway.
  curl -s -S -L -X GET "!base_url!/svc/log/!id!?severity=ERROR" --data-urlencode "msg=winpe_error:!stage2_script! not found or not downloaded."
)

@echo.
@echo.Stage2 script exit_code ... : !exit_code!
@echo.

@echo.Updating WinPE boot info (wpeutil.exe UpdateBootInfo) ...
wpeutil.exe UpdateBootInfo >NUL 2>&1
@echo.

@echo.
@echo.Rebooting the node ...
@echo.

wpeutil.exe reboot
@echo.

:EOF

exit /b !exit_code!

