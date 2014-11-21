# Powershell Script Module : ModuleUtils/ModuleUtils.psm1

Set-StrictMode  -Version  2.0
Set-PSDebug     -Trace    0
$ErrorActionPreference = "STOP"

$PSModuleListsDir = Join-Path $Env:PROGRAMDATA 'PSModules\Lists'

# ---- Manifest Utils -----------------------------------------------------

function Find-ModuleManifestDefaultsFile {
  [CmdLetBinding()] Param (
    [String[]]$Paths = @( (
      [String]$PWD,
      ($Env:PSModulePath -split ';'),
      ($Env:PSModulePath -split ';' | ?{ $_ -ilike "${Env:USERPROFILE}*" })
    ) | ?{$_} | %{$_} ) # Flatten
  )
  $Path     = $Paths[0]
  $Shifted  = $Paths[1 .. ($Paths.Length)]

  if ( $Path ) {
    Write-Verbose "Scanning Path : $Path, Test : $(ls **.psd1)"
    if ( Test-Path ($DefaultsFile = (Join-Path $Path "ModuleManifestDefaults.psd1")) ) {
      Write-Verbose "Found DefaultsFile : $DefaultsFile"
      return $DefaultsFile
    }
    if ( ($Parent = Split-Path $Path -Parent) ) { 
      $Shifted = ($Parent, $Shifted) | %{$_} # Flatten
    }
  }

  if ( -not($Shifted) ) { 
    Throw "Unable to find ModuleManifestDefaults file." 
  }
  return ($_ = & ($MyInvocation.MyCommand.Name) -Paths $Shifted)
}

function New-ModuleHelpFile {
  [CmdletBinding()] Param(
    [String]$Path
  )

  return

<#
Writing Help for Windows PowerShell Modules
 http://msdn.microsoft.com/en-us/library/windows/desktop/dd878343(v=vs.85).aspx
#>
}

function Get-ModuleManifest {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$False, ParameterSetName='Default')]
    [Parameter(Mandatory=$False, ParameterSetName='PathLocation')]
    [ValidateNotNullOrEmpty()]
    [Alias("Module","Name")]
      [String]$ModuleName,
    [Parameter(Mandatory=$False, ParameterSetName='Default')]
    [Parameter(Mandatory=$False, ParameterSetName='ManifestPath')]
    [Alias("Attribute","Property")]
      [String]$Field,
    [Parameter(Mandatory=$False, ParameterSetName='PathLocation')]
      [Switch]$PathLocation,
    [Parameter(Mandatory=$False, ParameterSetName='ManifestPath')]
      [String]$ManifestPath,
    [Parameter(Mandatory=$False, ParameterSetName='Default')]
      [Switch]$AllFields
  )

  $PSDFile = Switch -Regex ( $ParameterSetName = $PSCmdlet.ParameterSetName ) {
    'ManifestPath'  {    
      $ManifestPath 
      break
    }
    'Default'       {
      & $($MyInvocation.MyCommand.Name) -ModuleName $ModuleName -PathLocation
      break
    }
    'PathLocation'    {
      if ($Module = Get-Module -ListAvailable -Name $ModuleName | Select -First 1) {
        $ParentDir      = (Split-Path $Module.Path -Parent)
        $ModuleBaseName = (Split-Path $ParentDir -Leaf)
        return ($_ = Join-Path  $ParentDir "${ModuleBaseName}.psd1")
      }
      else {
        Throw "No candidate module found for '$ModuleName'"
      } 
      break
    }
    '.*'            {
      Throw "Unknown parameter set name : $ParameterSetName"
    }
  }

  if ( $PSDFile ) {
    if ( -not(Test-Path $PSDFile) ) {
      Throw "No manifest file ('$PSDFile') found for module '$ModuleName'."
    }

    if ( $ParameterSetName -imatch 'PathLocation' ) {
      return $PSDFile
    }

    try {
      $ManifestData = Read-PSDFile -Path $PSDFile
      if ( $Field ) {
        return $ManifestData.($Field)
      }
      else {
        return $ManifestData
      }
    }
    catch {
      Throw "Failed to read module manifest for module '$ModuleName'. $_"
    }
  }
  else {
    Throw "Error locating manifest file for modulle '$ModuleName'"
  }
}

function Get-ModuleManifestData {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)]
    [Alias("ManifestFile","Manifest","Path")]
      [String]$PSDFile,
    [Alias("Field")]
      [String]$Attribute,
    [Switch]$Force
  )
 
  $ManifestData = Read-PSDFile -Path $PSDFile
  if ($Attribute) {
    return $ManifestData.($Attribute)
  }
  
  $ManifestData
}

function Get-ModuleManifestDefault {
  [CmdletBinding()] Param(
    [String]$Path,
    [String]$Key
  )
  if ($Path) {
    $DefaultsFile = Find-ModuleManifestDefaultsFile -Path $Path
  } else {
    $DefaultsFile = Find-ModuleManifestDefaultsFile 
  }
  if ( $Key ) {
    Get-ModuleManifestData -Path $DefaultsFile -Field $Key
  } else {
    Get-ModuleManifestData -Path $DefaultsFile
  }
}

function New-ModuleManifest {
<#
.SYNOPSIS
Wrapper around New-ModuleMember to create a module manifest for a SAL package.
.ForwardHelpCategory    Cmdlet
.ForwardHelpTargetName  New-ModuleManifest
.NOTES
How to Write a Module Manifest
  http://msdn.microsoft.com/en-us/library/windows/desktop/dd878297(v=vs.85).aspx
New-ModuleManifest
  http://technet.microsoft.com/library/hh849709.aspx
#>
  [CmdletBinding()] Param (
    [Guid]      $Guid               = [Guid]::NewGuid(),
    [Object[]]  $ModuleList         = @(),
    [Object]    $PrivateData        = '',
    [Object[]]  $RequiredModules    = @(),
    [String[]]  $AliasesToExport    = '*',
    [String]    $Author             = (Get-ModuleManifestDefault -Key Author),
    [String]    $CmdletsToExport    = '*',
    [String]    $CompanyName        = (Get-ModuleManifestDefault -Key CompanyName),
    [String]    $Copyright          = "(c) $(Get-Date -UFormat '%Y'), $CompanyName. All rights reserved. $(Get-ModuleManifestDefault -Key Copyright)",
    [Parameter(Mandatory=$True)]
      [String]  $Description,
    [String[]]  $FileList           = @(),
    [String[]]  $FormatsToProcess   = @(),
    [String[]]  $FunctionsToExport  = @(),
    [String]    $ModuleToProcess    = '',
    [String[]]  $NestedModules      = @(),
    [Parameter(Mandatory=$True)]
      [String]  $Path,
    [String]    $PowerShellHostName = '',
    [ValidateSet("None","MSIL","X86","IA64","AMD64")]
      [String]  $ProcessorArchitecture          = 'None',
    [String[]]  $RequiredAssemblies             = @(),
    [String[]]  $ScriptsToProcess               = @(),
    [String[]]  $TypesToProcess                 = @(),
    [String[]]  $VariablesToExport              = '*',
    [System.Version]    $CLRVersion             = $Null,
    [System.Version[]]  $DotNetFrameworkVersion = $Null,
    [System.Version]    $ModuleVersion          = "0.1",
    [System.Version]    $PowerShellHostVersion  = $Null,
    [System.Version]    $PowerShellVersion      = "2.0"
  )

  if ( -not( $Path -imatch "\.psd1$" ) ) {
    $ModuleBaseName = Split-Path (Split-Path $Path -Parent) -Leaf
    $Path = Join-Path $Path "${ModuleBaseName}.psd1"
  }

  Write-verbose "Path : $Path"
  if ( -not($Parent = (Split-Path $Path -Parent -ea 0)) ) {
    $Parent = $PWD
  }

  if ( -not(Test-Path -PathType Container $Parent) ) {
    try {
      mkdir $Parent -Force -Verbose:$VerbosePreference | Out-Null
    } catch {
      throw "Unable to create directory '$Parent'" 
    }
  }
  Write-Verbose "Parent directory ($Parent), Path : $Path"

  # Populate $PSBoundParameters with our defaults in the function signature
  $MyInvocation.MyCommand.ParameterSets[0].Parameters | %{
    if ($var = Get-Variable -Name $_.Name -ea 0) {
      if ( -not($PSBoundParameters.ContainsKey($var.Name)) ) {
        $PSBoundParameters.Add($var.Name, $var.Value)
      }
    }
  }
  $PSBoundParameters['Path'] = $Path
  
  Microsoft.PowerShell.Core\New-ModuleManifest @PSBoundParameters
  Microsoft.PowerShell.Utility\Import-LocalizedData    `
      -BindingVariable  ManifestData                `
      -BaseDirectory    (Split-Path $Path -Parent)  `
      -Filename         (Split-Path $Path -Leaf)
  return $ManifestData
}

# ---- PSD Utils ----------------------------------------------------------

function Read-PSDFile {
  [CmdletBinding()] Param (
    [String]$Path,  
    [Switch]$Metadata
  )

  if ( -not($Path) ) {
    $Path = Find-ModuleManifestFile -CallStackFrameIndex 3
    Write-Host -Fore cyan "No path supplied, found $Path"
  }

  if ( ($Path -imatch '.psd1$') -and (Test-Path $Path -PathType Leaf) ) {
    if ( $Metadata ) {
      # Commented metadata to supplement the manifest data
      $MetadataTable = New-Object -TypeName PSObject
      Get-Content $Path | ?{
        $_ -imatch "^\s*#\s*'?[\w\d\-_]+'?\s*=\s*.+$" # Commented key=val pairs
      } | %{
        Write-Verbose "extract $_"
        if ( $Test = [Regex]::match($_, "^\s*#\s*'?([\w\d\-_]+)'?\s*=\s*('?.+'?)\s*$") ) {
          $MetadataTable = Add-Member -PassThru                       `
                            -InputObject $MetadataTable               `
                            -MemberType NoteProperty                  `
                            -Name ([String]$Test.Groups[1]).trim("'") `
                            -Value ([String]$Test.Groups[2]).trim("'")
        }
      }
      return $MetadataTable
    } else {
      # The actual manifest data
      # Import-LocalizedData -BindingVariable ModuleInfo -File "${ModuleName}.psd1" -BaseDirectory $ModulePath
      New-Object PSObject -Property ( Invoke-Expression ((Get-Content $Path) -join "`n") )
    }
  } 
  else {
    throw "Error reading PSD1 file '$Path', not a valid manifest file?"
  }

}

function Write-PSDFile {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)]
      [String]$Path,
    [Parameter(Mandatory=$True)]
      [HashTable]$Value,
    [String]$Comments = 'None',
    [HashTable]$Metadata,
    [Switch]$Force
  )

  if (  ( (Test-Path $Path) -eq $False )  `
      -or                                 `
        ( ((Test-Path $Path -PathType Leaf) -eq $True) -and ($Force) )
    ) {
    Set-Content -Path $Path -Value @"

# @{

#   InvocationCmd = '$($MyInvocation.Line)'
#            Date = '$(Get-Date -Format o)'
#          Author = '$($Env:USERNAME)@$($Env:COMPUTERNAME)'
#             PWD = '$($PWD)'
#        Comments = '$Comments'
# MetadataVersion = '0.1'

"@

    if ( $Metadata ) {
      $Metadata.Keys | Sort | %{
        $key = $_
        Add-Content -Path $Path -Value "#  '$key' = '$($Metadata.$key)'"
      }
    }
    Add-Content -Path $Path -Value @"

# }        

# -----------------------------------------------------------
#   WARNING: Edits to this file, may be lost or overridden.
#            Please use $($MyInvocation.MyCommand.ModuleName)\$($MyInvocation.MyCommand) 
#            to ensure this file's integrity.
# -----------------------------------------------------------

@{
"@
    $Value.Keys | Sort | %{
      $key = $_
      Add-Content -Path $Path -Value "  '$key' = '$($Value.$key)'"
    }
    Add-Content -Path $Path -Value @"
}

"@
  }
  elseif ( Test-Path $Path -PathType Leaf ) {
    throw "Error writing PSD1 file '$Path', file already exists."
  }
  else {
    throw "Unknown file type for '$Path', not a regular file?"
  } 
} 

# ---- Test Utils ---------------------------------------------------------

function Get-ModuleTests {
  [CmdletBinding()] Param(
    [Alias("Name")]
      [String]$ModuleName    
  )
  if ( Test-Path($PSDFile = Get-ModuleManifest -Name $ModuleName -PathLocation) ) {
    $Parent = Split-Path $PSDFile -Parent
    if ( Test-Path ($TestsDir = Join-Path $Parent "Tests/") ) {
      ls -R $TestsDir | ?{ -not($_.PSIsContainer) } | %{$_.FullName}
    }
  }
}

function Invoke-ModuleTests {
  [CmdletBinding()] Param(
    [Alias("Name")]
      [String]$ModuleName
  )
  Get-ModuleTests -Name $ModuleName | %{
    Write-Verbose "Invoking module test $ModuleName : $_"
    & "$_"
  }
}

# ---- Installer Utils ----------------------------------------------------

function Find-Module {
  [CmdletBinding()] Param(
    [Alias("Name")]     [String]$ModuleName = '.',
    [Alias("BasePath")] [String]$BasePaths = $Env:PSModulePath
  )

  # TODO
  #   Fail if path is not found in basepaths
  #   Fail if module is not found when scanning basepaths
  #   Error action preference
  $ModuleName = ($ModuleName.trim("\")) -replace "\\+", "\\"
  Write-Verbose "Locating module '$ModuleName' in $($BasePaths -split ';')"

  $OLDPWD = $PWD  # Save PWD, We are going to change/restore it
  $Candidates = $BasePaths -split ";" | ?{ $_ -imatch '\w' } | %{

    if ( Test-Path ($Path = $_) ) {
      $Path = (Resolve-Path $Path).ProviderPath   # Normalize and strip away PS provider artefacts
      Write-Verbose "Looking recursively under '$Path'"

     ls -R $Path -Include "*.psd1","*.psm1" | ?{ 
        if ( ( ($_.DirectoryName -imatch "$ModuleName$") -and (
               ( Test-Path (Join-Path $_.DirectoryName "$($_.BaseName).psm1") ) -or
               ( Test-Path (Join-Path $_.DirectoryName "$($_.BaseName).psd1") )
             ) ) -or ( 
               $_.BaseName -imatch "$ModuleName$" 
             ) ) 
        {
          Write-Verbose "  Candidate module '$_' matches filter '$ModuleName'"
          $True
        }

      } | %{ $_.Directory } | Get-Unique | %{
        cd $Path -ea 1 # Necessary for following Resolve-Path -Relative ..
        
        Write-Verbose "    Gathering metadata for '$($_.BaseName)'"
        $IsWellFormed = if ( 
                          ($SMExists = Test-Path ($ScriptModule   = Join-Path $_ "$($_.BaseName).psm1")) -and `
                          ($MMExists = Test-Path ($ModuleManifest = Join-Path $_ "$($_.BaseName).psd1"))
                        ) { $True } else { $False }

        $Object = New-Object -Type PSObject -Property @{
          BaseHierarchy   = ($Path);
          FullPath        = ($_.FullName);
          RelativePath    = ((Resolve-Path -Relative -Path $_.FullName).Trim(".\"));
          WellFormedName  = ($_.BaseName);
          IsWellFormed    = ($IsWellFormed);
          ModuleType      = if ($MMExists) { "Manifest" } else { "Script" }
          ModuleFile      = if ($MMExists) { ([System.IO.FileInfo]$ModuleManifest).Name } 
                            else { ([System.IO.FileInfo]$ScriptModule).Name }
        }

        if ( $Object.IsWellFormed -and (Test-Path ($PSDFile = Join-Path $Object.FullPath $Object.ModuleFile)) ) {
          $PSDFile = Read-PSDFile -Path $PSDFile
          $PSDFile | gm -MemberType NoteProperty | %{
            $Object | Add-Member NoteProperty $_.Name $PSDFile.($_.Name)
          }
        }

        return $Object
      }
    } 
    else {
      Throw "Path '$_' not found in basepaths '$BasePaths'."
    }

  }

  cd $OLDPWD
  if (-not($Candidates)) {
    Throw "No candidate modules for filter '$ModuleName' found in '$BasePaths'"
  } 
  $Candidates

<#
.SYNOPSIS
Find modules located in a given directory hierarchy.

.DESCRIPTION
Recursively scan a directory hierarchy and find all modules matching some given criteria.;;;
Returns a collection of objects for the modules found.

.EXAMPLE
Find-Module

Scan $Env:PSModulePaths recursively and list modules within.

.EXAMPLE
Find-Module -ModuleName "Foo" -BasePaths $PWD

Find well-formed modules named Foo in the current directory ($PWD) hierarchy.

.EXAMPLE
Find-Module -ModuleName "Foo\Bar\Baz" -BasePaths $Env:PSModulePath

Find module named "Foo\Bar\Baz" in every directory hierarchy listed in $Env:PSModulePath.
#>
}

function Update-ModuleInfoCache {
  [CmdletBinding()] Param(
    [String] $SourcePaths = $Env:PSModulePath,
    [Switch] $Force
  )
  
  begin {
    if ( -not(Test-Path $PSModuleListsDir) ) {
      mkdir $PSModuleListsDir -Force:$Force | Out-Null
    }
  }

  end {
    $SourcePaths -split ';' | ?{ $_ } | ?{ Test-Path $_ } | %{
      $ListFile = Join-Path $PSModuleListsDir ("{0}.list.xml" -f ($_ -replace '\\', '#'))
      $Modules  = Find-Module -ModuleName . -BasePaths $_ 
      $Modules | Export-CliXml -Path $ListFile -Force
      $Modules | %{
        ($Node, $Edges) = ($_, @())

        if ( Test-Member $Node ModuleToProcess ) { $Edges += $_.ModuleToProcess }
        if ( Test-Member $Node RequiredModules ) { $Edges += $_.RequiredModules }

        New-Node -Name $Node.WellFormedName -Edges $Edges -Attributes $Node
      }
    }
  }
}

function Get-ModuleInfoCache {
  [CmdletBinding()] Param(
    [String] $Source    
  )

  $ModuleInfoCache = @()

  # Get local cache
  if ( Test-Path $PSModuleListsDir ) {
    ls $PSModuleListsDir -Recurse -Include '*.list.xml' | %{
      if ($ModuleList = Import-CliXml $_) {
        $ModuleInfoCache += $ModuleList
      }
    }
  }

  return $ModuleInfoCache
}

function Resolve-ModuleDependencies {
  [CmdletBinding()] Param(
    [String]$ModuleName    
  )

  $ModuleInfoCache = Get-ModuleInfoCache

  Find-Module -ModuleName $ModuleName
}

function Install-Module {
  [CmdletBinding()] Param(
    [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
    [Alias("PSPath")]
      [String]$Module,
    [Parameter(Mandatory=$True)]
      [String]$BasePath,
    [Switch]$Global,
    [Switch]$Force
  )

  Begin {
    $MyCommand = $MyInvocation.MyCommand
  }

  Process {
    if ( -not(Test-Path $BasePath) ){
      mkdir $BasePath -Verbose:$VerbosePreference
    }

    $This = $_ 
    $NewParent = mkdir ([System.IO.FileInfo]($ParentName = Join-Path $BasePath $This.RelativePath)).Directory -Force:$Force -ea 0 -ev FailMkdir

    if ($FailMkdir) {
      switch ( $FailMkdir[0].CategoryInfo.Category ) {
        "ResourceExists"    { 
          throw "$MyCommand : Module parent directory already exists while trying to create '$ParentName'. WARNING: Using -force overwrites all files and data loss may ensue, use with caution." }
        "PermissionDenied"  { 
          throw "$MyCommand : Permission denied while trying to create '$ParentName'. You may need to be elevated to install under '$ParentName'." }
        *                   { 
          throw $FailMkdir }
      }
    }

    Write-Verbose "$MyCommand : Installing '$($This.FullPath)' to '$NewParent'"
    cp -Recurse $This.FullPath $NewParent -Force:$Force -ev FailCp
    if ($Failcp) { throw $FailCp }
  }

  End {}

  #  ## Get the Full Path of the module file
  #  $ModuleFilePath = Resolve-Path $ModuleFilePath
     
  #  ## Deduce the Module Name from the file name
  #  $ModuleName = (ls $ModuleFilePath).BaseName
     
  #  ## Note: This assumes that your PSModulePath is unaltered
  #  ## Or at least, that it has the LOCAL path first and GLOBAL path second
  #  $PSModulePath = $Env:PSModulePath -split ";" | 
  #                    Select -Index ([int][bool]$Global)
     
  #  ## Make a folder for the module
  #  $ModuleFolder = MkDir $PSModulePath\$ModuleName -EA 0 -EV FailMkDir
  #  ## Handle the error if they asked for -Global and don't have permissions
  #  if($FailMkDir -and @($FailMkDir)[0].CategoryInfo.Category -eq "PermissionDenied") {
  #    if($Global) {
  #      throw "You must be elevated to install a global module."
  #    } else { throw @($FailMkDir)[0] }
  #  }
     
  #  ## Move the script module (and make sure it ends in .psm1)
  #  Move-Item $ModuleFilePath $ModuleFolder
     
  #  ## Output A ModuleInfo object
  #  Get-Module $ModuleName -List

<#
.Synopsis
Installs a single-file (psm1 or dll) module to the ModulePath

.Description
Supports installing modules for the current user or all users (if elevated)

.Parameter ModuleFilePath
The path to the module file to be installed

.Parameter Global
If set, attempts to install the module to the all users location in Windows\System32...

.Example
Install-Module .\Authenticode.psm1 -Global

Description
-----------
Installs the Authenticode module to the System32\WindowsPowerShell\v1.0\Modules for all users to use.

.Example
Description
-----------
Uses Get-PoshCode (from the PoshCode module) to download the Impersonation module and then fixes 
the file name, and finally installs the Impersonation module for the current user.

.NOTES
Installing Modules
  http://msdn.microsoft.com/en-us/library/windows/desktop/dd878350(v=vs.85).aspx
#>

}

function New-ModuleFromScriptCollection {
#  JayKul's function http://poshcode.org/4391
  Throw "Function unimplemented."
}

# ---- Package Utils ------------------------------------------------------

function New-ScriptModule {
  [CmdLetBinding()] Param(
    [String]$Path,
    [String]$RandomString = $(Get-Date -Uformat "%s"),
    [Int32]$StrictVersion    
  )
@"
# PowerShell Script Module : <ModuleName>
Set-StrictMode  -Version 2.0    # Try and Ensure backwards compat with PS v2
Set-PSDebug     -Trace  0       # Tracing disabled, set to >=1 for tracing

$ErrorActionPreference="STOP"   # "STOP" sets in this module to abort on enountering errors.

# Required Development Guidelines
#   http://msdn.microsoft.com/en-gb/library/windows/desktop/dd878238(v=vs.85).aspx
# Strongly Encouraged Development Guidelines
#   http://msdn.microsoft.com/en-gb/library/windows/desktop/dd878270(v=vs.85).aspx
# Advisory Development Guidelines
#   http://msdn.microsoft.com/en-gb/library/windows/desktop/dd878291(v=vs.85).aspx

function New-Function$RandomString {
[CmdLetBinding()] Param(
  # [Parameter(ParameterSetName='DefaultParameterSet')]
)

Begin {}

Process {
  # Function body goes here.

}

End {}


# Function documentation below.
<#
.SYNOPSIS  
  This is one or two lines that briefly states the function's purpose.

.DESCRIPTION  
  This is an extended articulation of the function, its purpose,
  how it should be called, and and overview of how it lends itself to the 
  purpose of the current module.

.PARAMETER
  [PSObject]

.RETURNVALUE
  [PSObject]

.EXAMPLE
  New-Function -ParamFoo "foo"

.EXAMPLE
  New-Function -ParamBar "bar"

.NOTES  
  Function    : New-Function
  Module      : ThisModule
  Author      : <you>@citrix.com  
  Requires    : PowerShell V2  

  NOTES FOR USERS
    This contains notes for users of the module.

  NOTES FOR DEVELOPERS
    This contains notes for developers who may be interested in development/bug-fixingthis module.

.LINK  
  http://example.com/doc/this_module

#> 

}

# Control exports here
Export-ModuleMember -Function *-*

"@

return
<#
.SYNOPSIS
Create a new PowerShell Script Module (.psm1) file
.DESCRIPTION
Create a new PowerShell Script Module (.psm1) file
.NOTES
Required Development Guidelines
  * http://msdn.microsoft.com/en-gb/library/windows/desktop/dd878238(v=vs.85).aspx

Strongly Encouraged Development Guidelines
  * http://msdn.microsoft.com/en-gb/library/windows/desktop/dd878270(v=vs.85).aspx

Advisory Development Guidelines
  * http://msdn.microsoft.com/en-gb/library/windows/desktop/dd878291(v=vs.85).aspx
#>
}

function New-TestHierarchy {
  [CmdletBinding()] Param(
    [String]$Path    
  )

  return
}

# ---- Dependency Resolver ------------------------------------------------

function Resolve-NodeDependencies {
  [CmdLetBinding()] Param(
    [PSObject]  $Node,
    [PSObject]  $ParentNode,
    [ref]       $AvailableSelections,
    [ref]       $ResolvedNodes,   # TODO, this needs to be a pass-by-ref
    [ref]       $UnResolvedNodes, # TODO, this needs to be a pass-by-ref
    [Switch]    $Force
  )

  try {
    $NodeName = $Node.Name
  } catch { throw }

  if ( $UnResolvedNodes.Value.Contains($NodeName) ) {
    $err = "$($MyInvocation.MyCommand.Name), FATAL: Potential circular dependency detected while resolving Node ($Node).`n"+
           "  The Node ($Node) was previously marked for resolution but was not resolved."
    throw $err
  } else {
    $UnResolvedNodes.Value.Add($NodeName, 0) | Out-Null
  }

  $Msg = "{0,-16} : {1,-32} Parent: {2,-8} Node: {3,-8}" `
          -f "New node found", $NodeName, ($_=if($ParentNode){$ParentNode.Name}else{$Null}), $NodeName
  Write-Verbose ""
  Write-Verbose $Msg

  $EdgeCount = 0;
  # $Node.Edges | %{
  foreach ( $Edge in $Node.Edges ) {
    # $Edge     = $_
    $EdgeName = $Null
    Write-Verbose "  Examining edge ($Edge)."

    $EdgeName = Switch -Regex ( $EdgeType = $Edge.GetType() ) {
      'HashTable'   { $Edge.Keys;   break }
      'string'      { $Edge;        break }
      '.*'          {
        Throw "Type ($EdgeType) of Edge ($Edge) unrecognized/unsupported."
        break
      } 
    }

    if ( -not($ResolvedNodes.Value.Contains($EdgeName)) ) {
      if ( $UnResolvedNodes.Value.Contains($EdgeName) ) {
        $err = "$($MyInvocation.MyCommand.Name), FATAL: Potential circular dependency detected while resolving edge ($Edge).`n"+
               "  The Edge ($EdgeName) of Node ($Node) was previously marked for resolution but not resolved."
        if ( $Force ) { Write-Warning $err } else { throw $err }
      }
      else {
        if ( $AvailableSelections.Value[$EdgeName] ) {
          try {
            $Msg = "{0,-16} : {1,-32} Parent: {2,-8} Node: {3,-8} Edge: {4,-8}" `
                    -f "  Following edge", $EdgeName, ($_=if($ParentNode){$ParentNode.Name}else{$Null}), $NodeName, $EdgeName
            Write-Verbose $Msg

            Resolve-NodeDependencies                                            `
                  -Node                 ($AvailableSelections.Value[$EdgeName]) `
                  -AvailableSelections  ([ref]$AvailableSelections.Value)       `
                  -ResolvedNodes        ([ref]$ResolvedNodes.Value)             `
                  -UnResolvedNodes      ([ref]$UnResolvedNodes.Value)           `
                  -ParentNode           ($Node)                                 `
                  -Verbose:$VerbosePreference                                   `
                  -Force:$Force

            if ( $ResolvedNodes.Value.Contains($EdgeName) ) {
              $ResolvedNodes.Value[$EdgeName] = $ResolvedNodes.Value[$EdgeName] + 1;
            } else {
              $ResolvedNodes.Value[$EdgeName] = 1
            }
          } 
          catch { 
            if ( -not($Force) ) {
              throw
            } 
            else {
              switch -Regex ( $_.FullyQualifiedErrorId ) {
                '.*has no candidates.*' { Write-Warning "$_"; break; }
                .* { throw $_ }
              }
            }
          }
        } else {
          $Err =  "$($MyInvocation.MyCommand.Name) FATAL ERROR : Edge '$EdgeName' has no candidates. Possible dangling reference.`n" +
                  "  Last examined dependency chain = ParentNode($($ParentNode.Name))->Node($NodeName)->Edge($EdgeName)"
          Throw $Err
        }
      }
    } 
    else {
      $ResolvedNodes.Value[$EdgeName] = $ResolvedNodes.Value[$EdgeName] + 1; # weighting?
    }

    $EdgeCount++
  }


  # This may be superfluous, the only time this node can already be resolved
  # is when it may be resolved through a dependency (tree) of itself.
  # But then, don't we have for ourselves a circular dependency??
  if ( $ResolvedNodes.Value.Contains($NodeName) ) {
    $ResolvedNodes.Value[$NodeName] = $ResolvedNodes.Value[$NodeName] + 1; # weighting?
  } 
  else {
    $Msg = "{0,-16} : {1,-8} Closed:{2,3}  Open:{3,3}  Progress:{4,3}%" `
          -f "* Node resolved", $NodeName, ($ResolvedNodes.Value.Count), ($UnResolvedNodes.Value.Count), (100-$UnResolvedNodes.Value.Count)
    Write-Verbose $Msg
    $ResolvedNodes.Value.Add($NodeName, 1)
  }

  if ( $UnResolvedNodes.Value.Contains($NodeName) ) {
    $UnResolvedNodes.Value.Remove($NodeName)
  } else {
    if ( $ResolvedNodes.Value.Contains($NodeName) ) {
      throw "Something went wrong, $NodeName appears to have  already been resolved."
    } else {
      throw "Something went wrong, $NodeName appears to have not been marked for resolution."
    }
  }

}

function Get-NodeDependencies {
  [CmdLetBinding()] Param(
    [PSObject] $Node,
    [PSObject] $AvailableSelections,
    [Switch]   $Force
  )
  
  $Resolved   = New-Object System.Collections.Specialized.OrderedDictionary
  $UnResolved = New-Object System.Collections.Specialized.OrderedDictionary
  Resolve-NodeDependencies  -Node $Node                                       `
                            -AvailableSelections  ([ref]$AvailableSelections) `
                            -ResolvedNodes        ([ref]$Resolved)            `
                            -UnResolvedNodes      ([ref]$UnResolved)          `
                            -Force:$Force
  
  $Resolved | %{ 
    $Node=$_; 
    $Node.Keys | %{
      $Score = New-Object PSObject
      $Score | Add-Member NoteProperty NodeName   ($_)
      $Score | Add-Member NoteProperty Score      ($Node.($_))
      $Score | Add-Member NoteProperty NodeInfo   ($AvailableSelections.($_))
      Write-Output $Score
    };
  }
}

function New-Node {
  [CmdLetBinding()] Param(
    [Parameter(Mandatory=$True)]
    [Alias("Object")]
      [String]    $Name,
    [PSObject[]]  $Edges = @(),
    [PSObject]    $Attributes
  )
  $Node = New-Object PSObject |
    Add-Member -PassThru NoteProperty Name        $Name       |
    Add-Member -PassThru NoteProperty Attributes  $Attributes |
    Add-Member -PassThru NoteProperty Edges       $Edges      |
    Add-Member -PassThru ScriptMethod AddEdge     {
      Param(
        [PSObject[]] $Edges    
      )
      $this.Edges += $Edges
    }
  return $Node

<#
.SYNOPSIS
Define a new node in a dependency graph.
#>
}

function Test-NodeDependencies {
  [CmdLetBinding()] Param(
    [PSObject] $AvailableSelections,
    [PSObject] $RootNode,
    [Switch]   $Force
  )

  $AvailableSelections = @{
    'ModuleFoo'   = ( New-Node -Name 'ModuleFoo'   -Edges @( 'ModuleBar',  'ModuleBaz'  ) -Attributes @{} );
    'ModuleBar'   = ( New-Node -Name 'ModuleBar'   -Edges @( 'ModuleBaz',  'ModuleMoo'  ) -Attributes @{} );
    'ModuleBaz'   = ( New-Node -Name 'ModuleBaz'   -Edges @( 'ModuleFrob', 'ModuleFred' ) -Attributes @{} );
    'ModuleMoo'   = ( New-Node -Name 'ModuleMoo'   -Edges @( 'ModuleFred' )               -Attributes @{} );
    'ModuleQux'   = ( New-Node -Name 'ModuleQux'   -Edges @( )                            -Attributes @{} );
    'ModuleFrob'  = ( New-Node -Name 'ModuleFrob'  -Edges @( 'ModuleQux' )                -Attributes @{} );
  };

  # Get-NodeDependencies -Node $RootNode -AvailableSelections $AvailableSelections -Force:$Force
  Get-NodeDependencies -Node $AvailableSelections.('ModuleFoo') -AvailableSelections $AvailableSelections -Force:$Force
}

function Get-ModuleDependencies {
  [CmdLetBinding()] Param(
    [String]$Name,
    [HashTable]$AvailableSelections = @{}
  )

  $ManifestData = Get-ModuleManifest -Name $Name -AllFields
  $Edges = @($ManifestData.RequiredModules, $ManifestData.ModuleList) 

  $Node = New-Node -Name $ManifestData.ModuleToProcess -Edges $Edges -Attributes $ManifestData
  $Node.GetType()
  $AvailableSelections.($Name) = $Node
  $AvailableSelections.Keys
  $AvailableSelections
  Get-NodeDependencies -Node $Node -AvailableSelections $AvailableSelections 
}

# ---- PSModulePath Utils -------------------------------------------------

function Get-PSModulePath {
  [CmdletBinding()] Param(
    [String]$ModulePath,
    [ValidateSet('Machine','User','Process')] 
      [String]$Scope = 'Process'
  )

  Write-Host -Fore cyan "Scope: $Scope"

  $PSModulePath = if ( $Scope -match '^Process' ) {
    $Env:PSModulePath
  }
  else {
    [Environment]::GetEnvironmentVariable("PSModulePath", $Scope)
  }
  Repair-PSModulePath -Path $PSModulePath
}

function Repair-PSModulePath {
  [CmdletBinding()] Param(
    [String]$Path = (Get-PSModulePath -Scope 'Process')
  )

  $PSModulePath = (($Path).Trim(';') -replace ';;+',';') -split ';' | %{
    try { $_ = (Resolve-Path $_ -join ';')      } catch { }
    try { $_ = Convert-Path $_                  } catch { }
    try { $_ = if (Test-Path $_) { ([IO.DirectoryInfo]$_).FullName } else { $_ } } catch { }
    $_ = $_.TrimEnd('\')
    $_
  }

  return $PSModulePath -join ';'
<#
.SYNOPSIS
Clean up the given semicolon delimited $Path variable by
  * Removing empty paths (consequetive semicolons)
  * Trimming trailing slashes and semicolons from directory names
  * Converting paths from PSProvider types to directory strings
#>
}

function Set-PSModulePath {
  [CmdletBinding()] Param(
    [String]$ModulePath,
    [ValidateSet('Machine','User','Process')] 
      [String]$Scope = 'Process',
    [Boolean] $Permanent
  )

  if ( $Scope -match '^Process' ) {
    $Env:PSModulePath += ";$ModulePath"
  } 
  else {
    $PSModulePath = Repair-PSModulePath -Paths "$ModulePath"
    [Environment]::SetEnvironmentVariable("PSModulePath", $PSModulePath, $Scope)
  }
<#
.SYNOPSIS
Set the environment variable for $Env:PSModulePath with the given path.
#>
}

function Add-PSModulePath {
  [CmdletBinding()] Param(
    [String]$ModulePath,
    [ValidateSet('Machine','User','Process')] 
      [String]$Scope = 'Process',
    [Switch]$Prepend
  )

  Write-Host -Fore Cyan $ModulePath
  if ($CurrentValue = Get-PSModulePath -Scope $Scope) {
    $PSModulePath = Repair-PSModulePath -Path $CurrentValue
    $PSModulePath = if ( $Prepend ) { "$ModulePath;$CurrentValue" } else { "$CurrentValue;$ModulePath" }
    Set-ModulePath -ModulePath $PSModulePath -Scope $Scope
  }
  Get-PSModulePath -Scope $Scope

<#
.SYNOPSIS
Add the path to $Env:PSModulePath so that modules installed under it become discoverable in powershell sessions.
#>
}

function Remove-PSModulePath {
  [CmdletBinding()] Param(
    [String]$Path,
    [ValidateSet('Machine','User','Process')] 
      [String]$Scope = 'Process'
  )

  if ($CurrentValue = Get-PSModulePath -Scope $Scope) {
    $PSModulePath = Repair-PSModulePath -Path $CurrentValue
    $PSModulePath -split ';' | ?{ $_ -ne "$Path" }
    Set-PSModulePath -ModulePath $PSModulePath -Scope $Scope
  }
  Get-PSModulePath -Scope $Scope

<#
.SYNOPSIS
Removes $Path from the $Env:PSModulePath environment variable.
#>
}

# ---- Miscellaneous ------------------------------------------------------

function Add-Module {
  [CmdletBinding()] Param(
    [String]$ModuleName
  )

  if (-not(Get-Module -Name $ModuleName)) {
    Get-Module -ListAvailable -Name $ModuleName |
      Import-Module $ModuleName -Verbose:$VerbosePreference
  }
  else {
    return $false
  }
  return $true
}

function Test-Member {
  [CmdletBinding()] Param(
    [Parameter(Position=0)] [Alias('Object')] [PSObject]  $InputObject,
    [Parameter(Position=1)] [Alias('Name')]   [String]    $MemberName = '.',
    [Parameter(Position=2)] [ValidateSet('Method','NoteProperty','ScriptMethod', '.')]
      [String] $MemberType = '.',
    [Switch] $Return
  )

  if ( $Result =  $InputObject |
                  gm |
                  ?{ $_.MemberType -imatch $MemberType } |
                  ?{ $_.Name -imatch $MemberName } 
    ) {

    if ( $Return ) {
      return $Result
    }
    else {
      return ([Boolean] $Result)
    }

  }

  return $False
}

# function Test-Member {
#   [CmdletBinding()] Param(
#     [Parameter(ValueFromPipeline=$true)] [System.Management.Automation.PSObject] $InputObject,
#     [Parameter(Position=0)] [ValidateNotNullOrEmpty()] [System.String[]] $Name,
#     [Alias('Type')] [System.Management.Automation.PSMemberTypes] $MemberType,
#     [System.Management.Automation.PSMemberViewTypes] $View,
#     [Switch] $Static,
#     [Switch] $Force
#   )
#   Begin {
#     try {
#       $outBuffer = $null
#       if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
#       {
#         $PSBoundParameters['OutBuffer'] = 1
#       }
#       $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Get-Member', [System.Management.Automation.CommandTypes]::Cmdlet)
#       $scriptCmd = {& $wrappedCmd @PSBoundParameters | ForEach-Object -Begin {$members = @()} -Process {$members += $_} -End {$members.Count -ne 0}}
#       $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
#       $steppablePipeline.Begin($PSCmdlet)
#     }
#     catch { throw }
#   }
#   Process {
#     try {
#       $steppablePipeline.Process($_)
#     }
#     catch { throw }
#   }
#   End {
#     try {
#       $steppablePipeline.End()
#     }
#     catch { throw }
#   }
# 
# <#
# .ForwardHelpTargetName Get-Member
# .ForwardHelpCategory Cmdlet
# .URL
# http://www.tellingmachine.com/post/Test-Member-The-Missing-PowerShell-Cmdlet.aspx
# #>
# }

function defined {
  [CmdletBinding()] Param ( $Object )
  $Object -ne $Null
}

# ---- Exports ------------------------------------------------------------

Export-ModuleMember *

# ---- Module Notes -------------------------------------------------------
<#
.NOTES
Windows PowerShell Module Concepts
  http://msdn.microsoft.com/en-us/library/windows/desktop/dd901839(v=vs.85).aspx 
#>


