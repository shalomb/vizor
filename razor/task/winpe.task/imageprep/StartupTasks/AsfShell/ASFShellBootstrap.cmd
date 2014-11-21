@echo on

setlocal enabledelayedexpansion

set THISDIR=%~dp0

powershell -nologo -noprofile -noexit -file "!THISDIR!\ASFShellBootstrap.ps1"