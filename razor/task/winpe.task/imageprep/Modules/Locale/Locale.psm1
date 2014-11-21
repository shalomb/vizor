# Script Module Locale/Locale.psm1

Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0


function Get-Locale {                           #M:Locale
  [CmdletBinding()] Param()

  #ipmo international
  #Get-WinSystemLocale
  # http://msdn.microsoft.com/en-us/goglobal/bb964650
}


function Set-Locale {                           #M:Locale
  [CmdletBinding()] Param()
  # TODO
  # ...
}


# vim:sw=2:ts=2:et:foldexpr=getline(v\:lnum)=~'^\s*$'&&getline(v\:lnum-1)=~'^\s*$'&&getline(v\:lnum+1)=~'\S'?'<1'\:1:fdm=expr:filetype=ps1:ff=dos:fenc=ASCII

