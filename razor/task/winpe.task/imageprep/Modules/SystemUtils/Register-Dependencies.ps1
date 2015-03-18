Set-StrictMode -Version 2.0
$ErrorActionPreference = "STOP"
Set-PSDebug -Trace 0

# ---- Begin LoadDependantModules ----

Import-Module ModuleUtils
$RootModuleName = Split-Path -Leaf $PSScriptRoot
# Write-Host "RootModuleName : $RootModuleName"
# $ModuleEntry    = (Get-Module -ListAvailable $RootModuleName).Path # .ps[dm]1 file

Write-Verbose ""
Write-Verbose "Begin LoadDependantModules for $RootModuleName"

$RequiredModuleList = ModuleUtils\Get-ModuleManifest -Module $RootModuleName -Field ModuleList

$DepCount = foreach ( $RequiredModule in $RequiredModuleList ) {
  Switch -Regex ( $RequiredModule.GetType().Name ) {
    'HashTable' {
      $ModuleName     = $RequiredModule.ModuleName
      $ModuleVersion  = $RequiredModule.ModuleVersion
      $ModuleGuid     = $RequiredModule.GUID

      $Candidate = Get-Module -ListAvailable -Name $ModuleName | %{
        Write-Verbose "  RequiredModule  -> $ModuleName v$ModuleVersion ($ModuleGuid)"
        Write-Verbose "      ThisModule  -> $($_.Name) v$($_.Version) ($($_.Guid)) ($($_.Path))"
        $_
      } | ?{
        $IsCandidateTest =  ( [System.Version]($_.Version) -eq [System.Version]($ModuleVersion) ) -and `
                            ( $_.Guid -eq $ModuleGuid )
        Write-Verbose "     IsCandidate  -> $IsCandidateTest"
        $IsCandidateTest
      } | Select -First 1

      if ( -not( $Candidate ) ) {
        Throw "Unable to locate module dependency. ($ModuleGuid/$ModuleName v$ModuleVersion)"
      }

      $PSVer = $PSVersionTable.PSVersion
      Write-Verbose "  * PSVer=$PSVer, Importing module $Candidate"
      if     ( $PSVersionTable.PSVersion -ge [System.Version]'3.0' ) { # PS >= 3.0
        Import-Module -ModuleInfo $Candidate
      } 
      elseif ( $PSVersionTable.PSVersion -eq [System.Version]'2.0' ) { # PS = 2.0
        Import-Module -ModuleInfo $Candidate # -Version $ModuleVersion
      } 
      else { # PS = 1.0 or Monad
        Write-Warning "Unsupported PowerShell Version ($($PSVersionTable.PSVersion))"
        Write-Warning "  Attempting to load module without dependency checks anyway .. "
        Import-Module -Name $ModuleName -Verbose:$VerbosePreference
      }
      break
    }
    'String' {
      Write-Host -Fore cyan "Import-Module -Name $ModuleObject"
      Import-Module -Name $ModuleObject -Verbose:$VerbosePreference
      break
    } 
    '.*' {
      Throw "Unknown/Undefined handler for ModuleInfo Type '$_'. (ModuleInfo Object : '$RequiredModule')."
    }
  }
  return $True
}

Write-Verbose "  Loaded $DepCount dependencies for $RootModuleName."
Write-Verbose "End LoadDependantModules for $RootModuleName"
Write-Verbose ""

# ---- End LoadDependantModules ----


