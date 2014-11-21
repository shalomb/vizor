# Powershell Script Module : ModuleUtils/ModuleUtils.psm1

Set-StrictMode  -Version  2
Set-PSDebug     -Trace    0


function Test-SALPackage {
  [CmdLetBinding()]
  Param(
    [Switch]$IntegrityOnly,
    [Switch]$GenerateCheckSums
  )

  # Get-Module -ListAvailable
  #   - Lists script modules which don't have a manifest - GUID is blank
  # Test-ModuleManifest
  #   - Description may be blank
}


function New-SALPackage {
  [CmdLetBinding()]
  Param(
    [String]$Path,
    [String]$Description = '',
    [Switch]$Force
  )
  
  # Directory
  if ( -not(Test-Path $Path) -or ($Force) ) {
    mkdir -Force $Path | Out-Null
  } 
  else {
    throw "Directory '$Path' already exists .. aborting."
  } 

  $RootModuleName = Split-Path $Path -Leaf

  $Package = New-Object PSObject
  $Package | Add-Member NoteProperty RootModuleName $RootModuleName

  # New PSM1
  $ScriptModule = ModuleUtils\New-ScriptModule -Path $Path -StrictVersion 2
  $Package | Add-Member NoteProperty ScriptModule $ScriptModule
  
  # PSD1
  $ManifestFile = ModuleUtils\New-ModuleManifest -Path $Path -Description $Description
  $Package | Add-Member NoteProperty ManifestFile $ManifestFile

  # about_Module help file
  $ModuleHelpFile = ModuleUtils\New-ModuleHelpFile -Path $Path
  $Package | Add-Member NoteProperty ModuleHelpFile $ModuleHelpFile

  # New test hierarchy
  $TestHierarchy = ModuleUtils\New-TestHierarchy -Path $Path
  $Package | Add-Member NoteProperty TestHierarchy $TestHierarchy

  $Package

<#
.SYNOPSIS
Generate a new SAL package directory hierarchy and populate essential files from templates.
.DESCRIPTION
This is a convenience function that automatically generates a new SAL package directory 
hierarchy and populates the essential files from templates. This allows the user to then
begin development without having to consider all the intricacies of the SAL directory
hierarchy.

Please refer to the -full (Get-Help New-SALPackage -Full) documentation for this function 
for links to the guidelines for development of powershell modules that conform to the 
SAL specifications.

.PARAMETER Path
Directory to create the new package in.
.PARAMETER Force
USE WITH CAUTION, DATA LOSS LIKELY IF USED. Create directory if it already exists and
replace files within with new ones.
.NOTES
SAL Development Guidelines
  * http://mindtouch.eng.citrite.net/

Required Development Guidelines
  * http://msdn.microsoft.com/en-gb/library/windows/desktop/dd878238(v=vs.85).aspx

Strongly Encouraged Development Guidelines
  * http://msdn.microsoft.com/en-gb/library/windows/desktop/dd878270(v=vs.85).aspx

Advisory Development Guidelines
  * http://msdn.microsoft.com/en-gb/library/windows/desktop/dd878291(v=vs.85).aspx

Automation Documentation Library
  * http://automation.eng.citrite.net/docs/


#>
}


# vim:sw=2:ts=2:et:foldexpr=getline(v\:lnum)=~'^\s*$'&&getline(v\:lnum-1)=~'^\s*$'&&getline(v\:lnum+1)=~'\S'?'<1'\:1:fdm=expr:filetype=ps1:ff=dos:fenc=ASCII

