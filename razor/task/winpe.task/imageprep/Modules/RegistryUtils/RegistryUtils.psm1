# Script Module RegistryUtils/RegistryUtils.psm1

Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0



function Get-RegistryKeyPropertiesAndValues {   #M:RegistryUtils
  [CmdletBinding()]
  Param( 
    [Parameter(Mandatory=$true)] [string]$path
  )

  $properties = gp $path
  $properties | gm | ?{ $_.MemberType -eq "NoteProperty" -and !($_.Name -imatch '^PS') } | 
    Select-Object -ExpandProperty Name |
    %{
      New-Object PSObject -Property @{ 'value'=$properties.$_; 'property'=$_ }
    }
}


# vim:sw=2:ts=2:et:foldexpr=getline(v\:lnum)=~'^\s*$'&&getline(v\:lnum-1)=~'^\s*$'&&getline(v\:lnum+1)=~'\S'?'<1'\:1:fdm=expr:filetype=ps1:ff=dos:fenc=ASCII

