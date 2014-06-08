@echo off

set DEBUG=1

setlocal enabledelayedexpansion

set razor_server=[%RAZOR_SERVER%]
set base_url=http://!razor_server!:8080/svc
set stage2_script=second-stage.cmd

@echo.
@echo.Initializing network ...
@echo.

wpeutil.exe InitializeNetwork
set exit_code_initnet=!ERRORLEVEL!

@echo.
@echo.Initializing WinPE environment ...
@echo.

wpeinit
set exit_code_wpeinit=!ERRORLEVEL!

cd !temp!

:: Support DHCP Server discovery

:: Discover all MAC Addresses
if exist mac_addresses.txt del /f /q mac_addresses.txt
for /f "tokens=1,2 delims=:" %%g in ('ipconfig /all ^| find /i "Physical Address" ^| find /v /i "00-00-00-00-00-00"') do ( 
  set mac=%%h

  :: strip leading/trailing white space
  if "!mac:~-1!"==" " set mac=!mac:~0,-1!
  if "!mac:~0,1!"==" " set mac=!mac:~1!

  echo !mac! >> mac_addresses.txt
)

:: Join up mac addresses for the URL query
::   net0=00-15-5d-12-34-56&net1=00-15-5d-12-34-57
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

@echo.
@echo. Script ................... : Razor WinPE Bootstrap Script
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
@echo.    WPEInit ............... : !exit_code_wpeinit!
@echo.

@echo.
hostname
ipconfig /all | find /i "address"
ipconfig /all | find /i "server"
@echo.

:: Get Node ID from server
@echo.
@echo. ID Map Url ............... : !base_url!/nodeid?!hwid!
@echo.

if exist id.txt del /f /q id.txt
curl -q "!base_url!/nodeid?!hwid!" > id.txt

for /f "tokens=1,2 delims=:,}" %%g in ('type id.txt') do (
  set id=%%h
)

set stage2_url=!base_url!/file/!id!/second-stage.cmd

@echo.
@echo. Stage 2 Script Url ....... : !stage2_url!
@echo.

pause

curl -q "!stage2_url!" > !stage2_script!
notepad !stage2_script!
pause

if exist !stage2_script! (
  notepad !stage2_script!
  call !stage2_script!
  set exit_code=!ERRORLEVEL!
) else (
  echo.
  echo. --------------------------------------------------------------------------
  echo.# ERROR : Stage2 script '!stage2_script!' was not found or not downloaded. #
  echo. --------------------------------------------------------------------------
  echo.
  set exit_code=9009
)

@echo.
@echo.Stage2 script exit_code ... : !exit_code!
@echo.

start "Post-Bootstrap" cmd.exe
pause

@echo.
@echo.Rebooting the node ...
@echo.

if %DEBUG%==1 ( pause )
@echo. wpeutil.exe reboot
@echo.

exit /b !exit_code!

