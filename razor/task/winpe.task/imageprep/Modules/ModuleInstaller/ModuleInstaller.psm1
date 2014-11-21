Set-StrictMode -Version 2.0
$ErrorActionPreference = "STOP"


function Resolve-ModuleDependencies {

  [CmdletBinding()] Param(
    [String] $RootModuleName
  )

  $ModuleInfoCollection = @()

  ModuleUtils\Get-ModuleManifest -Module $RootModuleName -Field ModuleList | %{
    $RequiredModule = $_ 

    Switch -Regex ( $RequiredModule.GetType().Name ) {
      'HashTable' {
        $ModuleName     = $RequiredModule.ModuleName
        $ModuleVersion  = $RequiredModule.ModuleVersion
        $ModuleGuid     = $RequiredModule.GUID
  
        $Candidate = `
          Get-Module -ListAvailable -Name $ModuleName | %{
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
        
        $ModuleInfoCollection += $Candidate

        break
      }
      'String' {

        $Candidate = `
          Get-Module -ListAvailable -Name $RequiredModule.Name `
            | Sort-Object -Property Version `
            | Select -Last 1

        if ( -not( $Candidate ) ) {
          Throw "Unable to locate module dependency. ($ModuleName)"
        }

        $ModuleInfoCollection += $Candidate
        
        break
      } 
      '.*' {
        Throw "Unknown/Undefined handler for ModuleInfo Type '$_'. (ModuleInfo Object : '$RequiredModule')."
      }
    }
  }
  
  $ModuleInfoCollection
}

function Import-ModuleWithDependencies {
  
        $PSVer = $PSVersionTable.PSVersion
        if     ( $PSVersionTable.PSVersion -ge [System.Version]'3.0' ) { # PS >= 3.0
          Write-Verbose "  * Import-Module -Name $ModuleName -RequiredVersion $ModuleVersion # PSVer = $PSVer"
          Import-Module -ModuleInfo $Candidate -RequiredVersion $ModuleVersion
        } 
        elseif ( $PSVersionTable.PSVersion -eq [System.Version]'2.0' ) { # PS = 2.0
          Write-Verbose "  * Import-Module -Name $ModuleName -Version $ModuleVersion # PSVer = $PSVer"
          Import-Module -ModuleInfo $Candidate -Version $ModuleVersion
        } 
        else { # PS = 1.0 or Monad < 1.0
          Write-Warning "Unsupported PowerShell Version ($($PSVersionTable.PSVersion))"
          Write-Warning "  Attempting to load module anyway .. "
          Write-Warning "  Import-Module -Name $ModuleName -Verbose:$VerbosePreference # PSVer = $PSVer"
          Import-Module -Name $ModuleName -Verbose:$VerbosePreference
        }


}
