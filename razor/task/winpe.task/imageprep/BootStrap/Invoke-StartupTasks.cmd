@echo off

:: SYNOPSIS:
::    Startup script (V1.4) should be placed in the windows startup folder 
::    Copyright (c) Citrix Systems, Inc. All Rights Reserved.
 
:: DESCRIPTION
::    * Executes post-login, only progresses if the remoting client is not installed.
::    * Validates the network is up then copies and executes a automation bootstrap script

setlocal enabledelayedexpansion

set THISSCRIPT=%~nx0
set THISDIR=%~dp0
set STARTUPTASKSPS1=!THISDIR!\Invoke-StartupTasks.ps1
set STARTUPTASKSDIR=%~dp0\StartupTasks\


echo.
echo. !THISSCRIPT!
echo.
echo.   Current directory       : !THISDIR!
echo.   Startup tasks directory : !STARTUPTASKSDIR!
echo.   Startup tasks script    : !STARTUPTASKSPS1!
echo.

if not exist !STARTUPTASKSPS1! GOTO STARTUPTASKSPS1_NOT_FOUND
echo. Passing control to '!STARTUPTASKSPS1!'
echo.
powershell.exe -noprofile -nologo -executionpolicy bypass -file !STARTUPTASKSPS1!
exit /b !errorlevel!

:STARTUPTASKSPS1_NOT_FOUND
echo. !STARTUPTASKSPS1! not found.
exit /b 3


:: powershell.exe -noprofile -nologo -executionpolicy bypass -command "ls -R | ?{ (!$_.PSIsContainer) -and ($_ -imatch \"\.(cmd|bat|ps1|vbs|wsh)$\") } | Sort FullName"


:: :BEGIN
:: echo.*********************************************************************
:: echo.'!THISSCRIPT!' running startup tasks in '!STARTUPTASKSDIR!'
:: echo.*********************************************************************
:: for /f %%f in ('dir /s /b * ^| find /v /i "!THISSCRIPT!" ^| sort') do (
::   call :InvokeTask %%f 
::   if !errorlevel! NEQ 0 ( exit /b 1 !errorlevel! )
:: )
:: goto :END

:: :InvokeTask
:: set task_script=%1
:: set extension=%~x1
:: echo.
:: echo.  * Invoking '!task_script!' ...
:: echo.

:: if "%extension%"==".ps1" ( 
::   echo !task_script!; exit $lastexitcode 
::   echo !task_script!; exit $lastexitcode | powershell.exe -noprofile -nologo -executionpolicy bypass -command -
:: ) else (
::   call !task_script! 
:: )
:: set exit_code=!errorlevel!

:: echo.
:: echo.    exit_code: !exit_code!
:: echo.
:: if !exit_code! NEQ 0 ( call :TerminateWithWarning !task_script! !exit_code! )
:: exit /b !exit_code!
:: goto :EOF


:: :TerminateWithWarning
:: set task_name=%1
:: set ec=%2
:: echo.
:: echo. Task '!task_name!' failed with non-zero exit_code: !ec!
:: echo.
:: echo. A fatal error has occurred, processing of startup tasks has been stopped.
:: echo.  
:: pause >NUL 2>&1
:: exit /b !ec!

:: :END
:: exit /b 0
