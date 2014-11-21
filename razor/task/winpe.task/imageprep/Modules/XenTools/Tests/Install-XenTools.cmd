@echo on

powershell -nologo -noprofile -executionpolicy bypass -noexit -command "Import-Module XenTools -Verbose; if ( -not(Test-XenToolsInstallation -ea 0) ) { 'XenTools already installed.' } else { Install-XenTools -Verbose }"
