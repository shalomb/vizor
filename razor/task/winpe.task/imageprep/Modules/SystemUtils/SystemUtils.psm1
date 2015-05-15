# Script Module SystemUtils/SystemUtils.psm1

Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0
$ErrorActionPreference = "STOP"

[Void][System.Reflection.Assembly]::LoadWithPartialName('System.Core')

$CrashControlRegKey   = "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl"
$CrashControlRegKeyP  = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
# http://technet.microsoft.com/en-us/library/cc759418(v=ws.10).aspx


$Script:Win32_Bios  = $Script:Win32_ComputerSystem = $Script:Win32_ComputerSystemProduct =
$Script:Win32_OperatingSystem = $Script:Win32_Processor = $Script:Win32_SystemEnclosure = $Null

function Get-Win32_Bios {
  [CmdletBinding()] Param ( [Switch] $Force )
  if ( $Force -or -not($Script:Win32_Bios) ) {
    $Script:Win32_Bios = Get-WmiObject Win32_Bios
  }
  $Script:Win32_Bios
}

function Get-Win32_OperatingSystem {
  [CmdletBinding()] Param ( [Switch] $Force )
  if ( $Force -or -not($Script:Win32_OperatingSystem) ) {
    $Script:Win32_OperatingSystem = Get-WmiObject Win32_OperatingSystem
  }
  $Script:Win32_OperatingSystem
}
sal w32os Get-Win32_OperatingSystem

function Get-Win32_SystemEnclosure {
  [CmdletBinding()] Param ( [Switch] $Force )
  if ( $Force -or -not($Script:Win32_SystemEnclosure) ) {
    $Script:Win32_SystemEnclosure = Get-WmiObject Win32_SystemEnclosure
  }
  $Script:Win32_SystemEnclosure
}

function Get-Win32_Processor {
  [CmdletBinding()] Param ( [Switch] $Force )
  if ( $Force -or -not($Script:Win32_Processor) ) {
    $Script:Win32_Processor = Get-WmiObject Win32_Processor
  }
  return ,@($Script:Win32_Processor)
}

function Get-Win32_SystemEnclosure {
  [CmdletBinding()] Param ( [Switch] $Force )
  if ( $Force -or -not($Script:Win32_SystemEnclosure) ) {
    $Script:Win32_SystemEnclosure = Get-WmiObject Win32_SystemEnclosure
  }
  $Script:Win32_SystemEnclosure
}

function Get-Win32_ComputerSystem {
  [CmdletBinding()] Param ( [Switch] $Force )
  if ( $Force -or -not($Script:Win32_ComputerSystem) ) {
    $Script:Win32_ComputerSystem = Get-WmiObject Win32_ComputerSystem
  }
  $Script:Win32_ComputerSystem
}

function Get-Win32_ComputerSystemProduct {
  [CmdletBinding()] Param ( [Switch] $Force )
  if ( $Force -or -not($Script:Win32_ComputerSystemProduct) ) {
    $Script:Win32_ComputerSystemProduct = Get-WmiObject Win32_ComputerSystemProduct
  }
  $Script:Win32_ComputerSystemProduct
}


function Get-RandomString {
  [CmdletBinding()] Param (
    [Int64]   $Length = 8,
    [String[]]$Whitelist = '[A-Za-z0-9]',
    [String]  $JoinChar = "",
    [Switch]  $AsArray
  )

  [Regex] $FilterRegex = ($Whitelist | %{$_}) -join '|'
  Write-Verbose "FilterRegex : $FilterRegex"
  $AllowedChars = 0..255 | %{[Char]$_} | ?{ $_ -cmatch $FilterRegex }
  Write-Verbose "AllowedChars : $AllowedChars"

  if ( -not( $AllowedChars ) ) {
    Write-Error "Empty character set to select characters from, cannot proceed."
  }

  $Chars = @()
  while ( ($RemainingLength = $Length - $Chars.Count) ) {
    $Chars += @( Get-Random -InputObject $AllowedChars -Count $RemainingLength )
  }

  if ( $AsArray ) { $Chars } else { $Chars -join $JoinChar }
}

function New-TempFile {
  [CmdletBinding()] Param(
    [String] $Template   = "tmp-XXXXXXXX",
    [String] $ParentPath = $Env:TEMP,
    [Switch] $Directory,
    [Switch] $AsString
  )

  $match = [Regex]::Match($Template,'([X#]{2,})');
  Write-Verbose "New File : $ParentPath\$Template, FillChars : $Match, AsDir : $Directory, AsString : $AsString"

  if ($Len = $match.Value.Length) {
    $FileName = $Template -replace $Match.Value, (Get-RandomString -Whitelist '[A-Za-z0-9]' -Length $Len)
    $Path = (Join-Path $ParentPath $Filename)
    if ( $AsString ) {
      return $Path
    }
    elseif ( $Directory ) {
      New-Item -Path $Path -Type 'directory'
    }
    else {
      New-Item -Path $Path -Type 'file'
    }
  }
  else {
    # Template does not have placeholders,
    $Template = "${Template}-XXXXXXXX"
    if ( $PSBoundParameters.ContainsKey('Template') ) { $PSBoundParameters.Remove('Template') >$Null }
    $PSBoundParameters.Add('Template', $Template ) > $Null
    New-TempFile @PSBoundParameters
  }
}
Set-Alias mktemp New-TempFile

$Script:SystemInfo = $Null
function Get-SystemInfo {
  [CmdletBinding()] Param()
  if ( $Script:SystemInfo -eq $Null ) {
    $SI = systeminfo.exe /fo csv | ConvertFrom-CSV
    $Script:SystemInfo = New-Object PSObject
    $SI | gm -MemberType NoteProperty | %{
      $Key = $_.Name -replace '[\s\t)(}{:]+',''
      $Script:SystemInfo | Add-Member NoteProperty $Key $SI.($_.Name)
    }
    $Script:SystemInfo
  }
  return $Script:SystemInfo
}

function Start-SFC {
  [CmdletBinding()] Param(
    [Switch]$ScanNow = $True,
    [Switch]$ScanOnce,
    [Switch]$ScanBoot,
    [String]$ScanFile,
    [String]$VerifyFile,
    [String]$OffBootdir,
    [String]$OffWinDir,
    [Switch]$VerifyOnly
  )

  $SFCSTDERRFile = "$Env:TEMP\SFC.STDERR.log"
  $SFCArgs = @( )
  $SFCArgs =      if ( $ScanNow     ) { "/scannow" }
              elseif ( $ScanOnce    ) { "/scanonce" }
              elseif ( $ScanBoot    ) { "/scanboot" }
              elseif ( $ScanFile    ) { "/scanfile $ScanFile" }
              elseif ( $VerifyFile  ) { "/verifyfile $VerifyFile" }
              elseif ( $OffBootDir  ) { "/offbootdir $OffBootDir" }
              elseif ( $OffWinDir   ) { "/offwindir $OffWinDir" }
              elseif ( $VerifyOnly  ) { "/VerifyOnly" }

  Write-Verbose "Starting 'sfc.exe $SFCArgs'"
  $process = Start-Process -FilePath $(Join-Path "$Env:WINDIR\System32" sfc.exe) `
              -ArgumentList $SFCArgs -PassThru -NoNewWindow `
              -RedirectStandardError "$SFCSTDERRFile"
  if ( -not $process ) {
    throw "Error invoking 'sfc.exe $SFCArgs'"
  } else {
    $Process | Select *path*,*id,*name,*title* | %{ Write-Verbose "  $_" }
    Write-Verbose "  Waiting for process to end"
    $process | Wait-Process
    $ExitCode = if   ( $Process.ExitCode ) { $Process.ExitCode } else { -3 }
  }

  Write-Verbose "  ExitCode : $($process.ExitCode)"
  switch -Regex ( $Process.ExitCode ) {
    '^0$' { Write-Verbose "SFC finished successfully."; break; }
    '.*'  {
      Write-Warning "SFC did not finish successfully. ExitCode: $($Process.ExitCode)"
      (cat $SFCSTDERRFile) -join "`n" | Write-Error
    }
  }

  return $process.ExitCode
}

function Get-Driver {
  [CmdletBinding()] Param(
    [Switch]$Extended
  )

  if ( $Extended ) {
    & driverquery.exe /FO CSV /v | ConvertFrom-CSV | %{
      $_."Accept Stop"   = if ( $_."Accept Stop"  -eq "TRUE" ) { $True } else { $False }
      $_."Accept Pause"  = if ( $_."Accept Pause" -eq "TRUE" ) { $True } else { $False }
      $_
    } | sort "Module Name", Description -CaseSensitive
  } else {
    & driverquery.exe /FO CSV /SI | ConvertFrom-CSV | %{
      $_.IsSigned = if ( $_.IsSigned -eq "TRUE" ) { $True } else { $False }
      $_
    } | sort DeviceName -CaseSensitive
  }
}

function Set-DriverVerifierSetting {
  [CmdletBinding()] Param(
    [Switch]$EnableStandard,
    [Switch]$Query,
    [Switch]$Reset
  )

  if ( $EnableStandard ) {
    & verifier.exe /standard /all
  }
  elseif ( $Query ) {
    & verifier.exe /querysettings
  }
  elseif ( $Reset ) {
    & verifier.exe /reset
  }
}

function Get-DriverVerifierSetting {
  [CmdletBinding()] Param() $Result = New-Object PSObject
  & verifier.exe /querysettings 2>$Null | %{
    if ( ($match = [Regex]::Match($_,'^([^:]+):(.*)$')) -and ($match.success) ) {
      $Result | Add-Member NoteProperty $match.Groups[1].Value $match.Groups[2].Value
    }
  }
  $Result
}

function Get-TaskList {
  [CmdletBinding()] Param(
    [String]    $Module,
    [String]    $UserName,
    [String[]]  $Filter,
    [Switch]    $Service,
    [ValidateSet('Running','Not Responding', 'Unknown')]
      [String]  $Status,
    [Switch]    $ByModule
  )

  if ( $ByModule ) {
    $Module = if ( $Module ) { $Module.ToLower() } else { '.' }
    Get-TaskList | % -begin {
      $ModulePidMap=@{}
    } -process {
      $Pid=$_.PID
      $_.Modules.ToLower() -split ',' | ?{ $_ -notlike 'n/a' } |
        ?{ $_ -match $Module } |
        % -process {
          if ( -not($ModulePidMap.Contains($_)) ) {
            $ModulePidMap.$_ = @()
          }
          $ModulePidMap.$_ += $Pid
        }
    } -end {
      $ModulePidMap.Keys | %{
        New-Object PSObject -Property @{ 'Module'=$_; 'ProcessIds'=$ModulePidMap.$_; }
      }
    }
  }
  elseif ( $Module ) {
    & tasklist.exe /fo csv /m "$Module*" | ConvertFrom-CSV | %{
      $_ | Add-Member -Force -PassThru NoteProperty `
            Modules (,($_.Modules -split ',' | ?{ $_ -inotmatch 'N/A' }))
    }
  }
  elseif ( $UserName ) {
    & tasklist.exe /v /fo csv /fi "UserName eq $UserName" | ConvertFrom-CSV
  }
  elseif ( $Filter ) {
    $FilterCmd = $Filter | %{ "/fi '$_'" }
    $cmd = "tasklist.exe /v /fo csv $FilterCmd | ConvertFrom-CSV"
    Invoke-Expression $cmd
  }
  elseif ( $Service ) {
    & tasklist.exe /fo csv /svc | ConvertFrom-CSV | %{
      $_ | Add-Member -Force -PassThru NoteProperty `
            Services (,($_.Services -split ',' | ?{ $_ -inotmatch 'N/A' }))
    }
  }
  else {
    & tasklist.exe /m /fo csv | ConvertFrom-CSV
  }
}

function Get-DotNetVersion {
  [CmdletBinding()] Param(
    [Switch] $System
  )

  if ( $System ) {
    return ([System.Runtime.InteropServices.RuntimeEnvironment]::GetSystemVersion())
  }

  $RegQueryPaths = @()
  $RegQueryPaths += @(ls "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\")
  if ( Test-Path ($rpath = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4*') ) {
    $RegQueryPaths += @(ls (Join-Path $rpath '\*') | ?{ $_.PSIsContainer })
  }

  $RegQueryPaths | %{
    $record   = Get-ItemProperty -Path $_.PSPath | %{ $_ | Select * -ExcludeProperty PS* }
    $record | Add-Member NoteProperty NDPPath $_ -Force

    if ( -not(Get-ItemProperty -Path $_.PSPath -Name Increment -ea 0) ) {
      $record | Add-Member NoteProperty Increment 0 -Force
    }
    $record
  }
}

function Test-DotNet35 {
  [CmdletBinding()] Param()
  Test-Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5"
}

function Install-DotNet35 {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)] $SxSSourcePath,
    [Switch] $Force
  )

  Write-Verbose "Installing .Net3.5 from $SxSSourcePath"

  if (-not($Force) -and (Test-DotNet35)) {
    Write-Verbose ".Net3.5 appears to be installed. Aborting.."
    return $True
  }

  if ( Import-Module ServerManager -ea 0 ) {
    Write-Verbose "Installing .Net 3.5 using Windows Roles and Features (ServerManager\Add-WindowsFeature)."
    Add-WindowsFeature -Name NET-Framework-Features -Source $SxSSourcePath
  }
  else {
    Write-Verbose "Installing .Net 3.5 using DISM (dism.exe ... /enable-feature /featurename:NetFX3 ...)"
    & dism.exe /online /enable-feature /featurename:NetFX3 /All /Source:$SxSSourcePath /LimitAccess
  }
}

function Get-Ngen {
  [CmdletBinding()] Param (
    [Switch] $Current
  )

  $CurrentNgen = Join-Path ([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'ngen.exe'

  if ( $Current ) {
    return ($CurrentNgen | ?{ Test-Path $_ })
  }

  ((Join-Path $Env:WinDir 'Microsoft.NET\Framework*\*\ngen.exe'), $CurrentNgen) |
      %{ Resolve-Path $_ -ea 0 | %{ ls $_ -ea 0 } } | ?{ Test-Path $_ } | Get-Unique
<#
.SYNOPSIS
Get the versions of ngen available for the installed .NET frameworks

.PARAMETER Current
Get the ngen for the current (process) .NET runtime
#>
}

function Get-NgenTask {
  [CmdletBinding()] Param (
    [Switch] $Current
  )

  $CurrentNgen = Join-Path ([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'ngentask.exe'

  if ( $Current ) {
    return ($CurrentNgen | ?{ Test-Path $_ })
  }

  ((Join-Path $Env:WinDir 'Microsoft.NET\Framework*\*\ngentask.exe'), $CurrentNgen) |
      %{ Resolve-Path $_ -ea 0 | %{ ls $_ -ea 0 } } | ?{ Test-Path $_ } | Get-Unique

<#
.SYNOPSIS
Get the versions of ngentask.exe available for the installed .NET frameworks

.PARAMETER Current
Get the ngen for the current (process) .NET runtime
#>
}

function Add-AssemblyToNgenQueue {
  [CmdletBinding()] Param(
    [String[]]  $Assemblies = @(),
    [String[]]  $Directories,
    [Alias('PowerShellAssemblies')]
      [Switch]  $CurrentDomainAssemblies,
    [String]    $ngen = (Get-Ngen -Current),
    [Switch]    $Force
  )


  if ( $CurrentDomainAssemblies ) {
    $Assemblies += @([AppDomain]::CurrentDomain.GetAssemblies() | ?{$_.Location} | %{ $_.Location })
  }

  if ( $Directories ) {
    $Assemblies += @($Directories | %{ ls -Recurse -Include '*.exe','*.dll' } | %{$_.FullName})
  }

  $Assemblies | %{
    Write-Verbose "$ngen install $_ /queue"
    & $ngen install $_ /queue | Write-Verbose
  }
}

function Start-NgenQueuedTasks {
  [CmdletBinding()] Param (
    [ValidateSet(1,2,3)]
      [Int32[]] $PriorityLevels = (1..3 | Sort -Descending),
    [Switch]    $Update = $True,
    [Switch]    $Force,
    [String[]]  $ngen
  )

  # Not set in parameter due to PS coercing array into string
  $ngen = if ( -not($ngen) ) { Get-Ngen }

  # https://msdn.microsoft.com/en-us/magazine/cc163808.aspx

  foreach ($ngenexe in $ngen) {
    Write-Verbose "Starting tasks using ngen '$ngenexe'"

    if ( $Update ) {
      Write-Verbose "$ngenexe update /queue /nologo # $Force"
      if ( $Force ) {
        & $ngenexe update /queue /nologo /force | Write-Verbose
      }
      else {
        & $ngenexe update /queue /nologo | Write-Verbose
      }
    }

    $PriorityLevels | %{
      Write-Verbose "$ngenexe ExecuteQueuedItems $_"
      & $ngenexe ExecuteQueuedItems $_ /nologo | Write-Verbose
    }

    Write-Verbose "$ngenexe queue continue"
    & $ngenexe queue continue /nologo  | Write-Verbose
  }
}

function Get-NgenService {
  [CmdletBinding()] Param(
    [Switch] $Name,
    [String[]] $ngen
  )

  # Not set in parameter due to PS coercing array into string
  $ngen = if ( -not($ngen) ) { Get-Ngen }

  foreach ($ngenexe in $ngen) {
    Write-Verbose "$ngenexe queue status"
    $clr = & $ngenexe queue status /nologo    | ?{ $_ -imatch 'clr' }
    $SvcName = $clr | %{
      [String]([Regex]::Match($_,':\s*(\S.*)\s*')).Groups[1].Captures[0]
    }
    if ( $Name ) {
      $SvcName
    } else {
      Get-Service -Name $SvcName
    }
  }
}

function Disable-SystemResoreOnLocalDrives {
  [CmdletBinding()] Param() gwmi -Class Win32_LogicalDisk    |
    ?{ $_.DriveType -eq 3 } |
    %{ Disable-ComputerRestore -Drive $_.DeviceID; }
}

function Start-Defrag {
  [CmdletBinding()] Param(
    $drive = $Env:SystemDrive ) Write-Verbose "Starting 'defrag.exe -f -v $drive'"
  & defrag.exe -f -v $drive
}

function Start-DefragOnLocalDrives {
  [CmdletBinding()] Param() gwmi Win32_LogicalDisk -filter 'Description="Local Fixed Disk" and FileSystem="NTFS"' |
    %{ Start-Defrag $_.Name }
}

function Get-SC {
  [CmdletBinding()] Param()
  Write-Verbose "Collecting 'sc.exe queryex' data"
  $foo = sc.exe queryex | ?{ $_ -imatch ":" } | %{
    $_ = $_ -replace "^[\ \t]+|[\ \t]+$";
    $_ -split "[\ \t]*:[\ \t]*"
  }

  $big=@(); $ary=@();
  $foo | %{
    if ( ($ary.count) -and ($_ -imatch "^SERVICE_NAME")) { $big +=, $ary; $ary = @(); }
    $_ = if ($_ -cmatch '^[0-9A-Z_]+$') { $_.ToLower(); } else { $_ }
    $ary +=, $_
  }

  $sc_service = @{}
  $big | %{
    $hash = @{}; $list = $_

    # Gather inner array into hash
    while ($list) {
      $key, $value, $list = $list;
      $hash[$key] = $value
    }

    # This service's name
    $service_name = $hash.service_name

    $sc_service[$service_name] = $hash
  }
  Write-Verbose "  .. done"

  Write-Verbose "Collecting data"
  $win32_service_keys     = (Gwmi -Class Win32_Service)[0]      | gm | ?{ ($_.MemberType -imatch "property") -and -not($_.Name -imatch "(?:^__|^PS|ClassName)") } | %{ $_.Name }
  $win32_service          = (Gwmi -Class Win32_Service)
  $win32_baseservice_keys = (Gwmi -Class Win32_BaseService)[0]  | gm | ?{ ($_.MemberType -imatch "property") -and -not($_.Name -imatch "(?:^__|^PS|ClassName)") } | %{ $_.Name }
  Write-Verbose ($win32_baseservice_keys -join ", ")
  $win32_baseservice      = (Gwmi -Class Win32_BaseService)
  $ps_service_keys        = (Get-Service)[0]                    | gm | ?{ ($_.MemberType -imatch "property") -and -not($_.Name -imatch "(?:^__|^PS|ClassName)") } | %{ $_.Name }
  $ps_service             = (Get-Service)
  Write-Verbose "  .. done"

  Write-Verbose "Creating Objects "
  $ps_service | %{
    $hash = @{}; $this = $_; $ServiceName = $this.ServiceName
    Write-Verbose "  * $ServiceName .. "
      Write-Verbose "    * PS Get-Service"
      $ps_service_keys | %{ if ($this.$_) { Write-Verbose "       $_"; try { $hash.$_ = $this.$_ } catch [Exception] {} } }

      Write-Verbose "    * Win32_Service"
      $win32_service_keys | %{ Write-Verbose "       $_"; try { $hash.$_ = $Win32_Service[$ServiceName].$_ } catch [Exception] {} }

      Write-Verbose "    * Win32_BaseService"
      $win32_BaseService_Keys | %{ Write-Verbose "         $_"; try { $hash.$_ = $Win32_BaseService[$ServiceName].$_ } catch [Exception] {} }

    try {
      Write-Verbose "    * SCInfo"
      $hash."SCInfo" = if ($sc_service[ $ServiceName ]) { $sc_service[ $ServiceName ] } else { @{} }
    } catch [Exception] {}

    $service = New-Object -TypeName PSObject
    $hash.keys | sort | %{
      Add-Member -InputObject $service -MemberType NoteProperty -Name $_ -Value $hash.$_
    }
    $service
  }
  Write-Verbose "  .. done"

  #   # Process gwmi Win32_Service for this service
  #   $win32_service = Gwmi -Class Win32_Service -Filter "Name='$service_name'"
  #   $win32_service_keys | %{ $hash."$_" = $Win32_Service."$_" }

  #   # Process Get-Service for this service
  #   $ps_service = Get-Service -Name $service_name
  #   $ps_service_keys | %{ $hash."$_" = $ps_service."$_" }

}

function Show-DiskUtilization {
  [CmdletBinding()] Param(
    $Factor = 1GB
  )
  Gwmi -Class Win32_LogicalDisk | ?{ $_.FreeSpace -ge 0 } | %{
    $df = New-Object PSObject
    $df | Add-Member NoteProperty Device      ( $_.DeviceID )
    $df | Add-Member NoteProperty Size        ( "{0:N4}"  -f ( $_.Size      / $Factor ) )
    $df | Add-Member NoteProperty Used        ( "{0:N4}"  -f ( ($_.Size - $_.FreeSpace) / $Factor ) )
    $df | Add-Member NoteProperty Available   ( "{0:N4}"  -f ( $_.FreeSpace / $Factor ) )
    $df | Add-Member NoteProperty Utilization ( "{0:N4}%" -f ( 100*(($_.Size - $_.FreeSpace)/$_.Size) ) )
    Write-Output $df
  }

<#
.SYNOPSIS
Show disk space utilization

.EXAMPLE
Show-DiskUtilization -Factor 1MB
#>
}

sal Get-DiskUtilization Show-DiskUtilization
sal df                  Show-DiskUtilization

function Get-SMBBlockSigning {
  [CmdletBinding()] Param() Write-Verbose "Disabling SMB Block Signing."
  $ESS = Get-ItemProperty "HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters" | Select-Object -ExpandProperty EnableSecuritySignature -ea 0
  $RSS = Get-ItemProperty "HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters" | Select-Object -ExpandProperty RequireSecuritySignature -ea 0
  $Res = New-Object PSObject
  $Res | Add-Member NoteProperty EnableSecuritySignature  $ESS
  $Res | Add-Member NoteProperty RequireSecuritySignature $RSS
  $Res
}

function Invoke-Robocopy {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True,Position=1)]
      [String]$SourceDir,
    [Parameter(Mandatory=$True,Position=2)]
      [String]$DestinationDir,
    [Alias("Files","FileList")]
      [String[]]$FileGlob = @('*.*'),
    [String[]]$Options,
    [Switch]$Mirror,
    [Switch]$Help
  )
  if (-not(gcm ($Robocopy = (Join-Path "$Env:WINDIR" "System32\robocopy.exe")))) {
    Throw "Robocopy.exe ($Robocopy) not installed."
  }

  if ( $Help ) {
    & $Robocopy /?
  }

  if ( $Mirror ) {
    "-" * 79
    Write-Host -Fore Cyan "  & $Robocopy $SourceDir $DestinationDir /mir $Options"
    "-" * 79
    & $Robocopy $SourceDir $DestinationDir /mir $Options
  }
  else {
    "-" * 79
    Write-Host -Fore Cyan "  & $Robocopy $FileGlob $SourceDir $DestinationDir $Options"
    "-" * 79
    & $Robocopy $FileGlob $SourceDir $DestinationDir $Options
  }
}

function Invoke-RegJump {
  [CmdletBinding()] Param(
    [String]$Key
  )
  Write-Verbose "Key : $Key"
  $Key = Resolve-Path $Key
  Write-Verbose "    : $Key"
  if ( gcm regjump.exe ) {
    & regjump.exe $Key
  }
  else {
    Throw "regjump.exe not installed or not available."
  }
}

function Install-SysInternalsTools {
# TODO: Make a Generic robocopy installer
  [CmdletBinding()] Param(
    [String]$SysInternalsSource,
    [String]$SysInternalsBin
  )
  Write-Verbose "Installing the SysInternals tools to $SysInternalsSource -> $SysInternalsBin"
  if (-not (Test-Path $SysInternalsBin)) { mkdir -Force $SysInternalsBin | Out-Null }
  Write-Host xcopy /v /e /s /Y  $SysInternalsSource $SysInternalsBin
  & xcopy /v /e /s /Y           $SysInternalsSource $SysInternalsBin
}

function Initialize-Sysinternals {
  [CmdletBinding()] Param() Write-Verbose "Accepting EULAs for SysInternals utilities."
  "BGInfo","C","Contig","Coreinfo","NTFSInfo","PsInfo","SDelete" | %{
    Write-Verbose "  '$_'"
    & reg.exe add (Join-Path "HKCU\SOFTWARE\Sysinternals" $_) /v EulaAccepted  /t REG_DWORD /d 1 /f | Write-Verbose
  }
}

function Get-SMBBlockSigning {
  [CmdletBinding()] Param(
    [Switch] $LanManServer,
    [Switch] $LanManWorkStation
  )

  $Paths = @()

  if ( $LanManServer ) {
    $Paths += @( "HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters" )
  }

  if ( $LanManWorkStation ) {
    $Paths += @( "HKLM:\System\CurrentControlSet\Services\LanManWorkStation\Parameters" )
  }

  foreach ( $Path in $Paths ) {
    gp -Path $Path | Select -Exclude PS* *
  }
}

function Set-SMBBlockSigning {
  [CmdletBinding()] Param(
    [Switch] $Enabled,
    [Switch] $LanManServer,
    [Switch] $LanManWorkStation
  )
  Write-Verbose "Disabling SMB Block Signing."

  $Paths = @()

  if ( $LanManServer ) {
    $Paths += @( "HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters" )
  }

  if ( $LanManWorkStation ) {
    $Paths += @( "HKLM:\System\CurrentControlSet\Services\LanManWorkStation\Parameters" )
  }

  foreach ( $Path in $Paths ) {
    sp -Path $Path -Name "EnableSecuritySignature"  `
        -Type DWORD -Value ([Boolean]$Enabled) -Force -Verbose:$VerbosePreference
    sp -Path $Path -Name "RequireSecuritySignature" `
       -Type DWORD -Value ([Boolean]$Enabled) -Force -Verbose:$VerbosePreference
  }
}

function Disable-SMBBlockSigning {
  [CmdletBinding()] Param()
  Set-SMBBlockSigning -Enabled:$False -Verbose:$VerbosePreference
}

function Enable-SMBBlockSigning {
  [CmdletBinding()] Param()
  Set-SMBBlockSigning -Enabled:$True -Verbose:$VerbosePreference
}

function defined {
  [CmdletBinding()] Param ( $Object ) $Object -ne $Null
}

function Get-ObjectQuery {
  [CmdletBinding()] Param(
    [Regex]$KeyRegex    = '.*',
    [Regex]$ValueRegex  = '.*',
    [Object]$InputObject,
    [Switch]$Properties,
    [Switch]$PropertiesFromPropertySets,
    [Switch]$Dereference
  )

  # TODO : PropertySets
  if ( $Properties ) {
    $Names = $InputObject | gm | ?{
      ($_.MemberType -ilike "Property*") -and ($_.Name -imatch ([String]$KeyRegex))
    } | %{ $_.Name }
    return $Names
  }
  elseif ( $KeyRegex -and $ValueRegex ) {
    $TargetProperties = & ($MyInvocation.MyCommand.Name) @PSBoundParameters -Properties
    if (-not($TargetProperties) ) {
      Throw "No Properties matching KeyRegex '$KeyRegex' on Object '$InputObject'"
    }
    $Result = New-Object PSObject
    $FlattenedResult = @()
    $Match = $False;
    $InputObject | % {
      $ThisObject = $_;
      $TargetProperties | %{
        if ($ThisObject.($_) -imatch ([String]$ValueRegex)) {
          $Match = $True
          if ( $Dereference ) {
            $FlattenedResult += @( $ThisObject.($_) )
          } else {
            $Result | Add-Member NoteProperty $_ ($ThisObject.($_)) -Force
          }
        }
      }
    }
    if ( -not($Match) ) {
      Throw "Empty resultset or non-match on $($MyInvocation.MyCommand.Name) -InputObject $InputObject -KeyRegex '$KeyRegex' -ValueRegex '$ValueRegex'"
    } else {
      return ($_ = if ( $Dereference ) { $FlattenedResult } else { $Result })
    }
  }
  else {
    Throw "Unsupported query type."
  }
}

function Get-WMIClassEnumeration {
  [CmdletBinding()] Param(
    [Regex] $ClassNameRegex
  )
  $ManagementClass = New-Object System.Management.ManagementClass
  $EnumOptions = New-Object System.Management.EnumerationOptions
  $EnumOptions.EnumerateDeep = $True
  $Result = $ManagementClass.PSBase.GetSubClasses( $EnumOptions )

  if ( $ClassNameRegex ) {
    $Result = $Result | ?{ ([String]$_.Name).ToLower() -imatch $ClassNameRegex }
  }

  $Result
}

function Get-WMIQuery {
  [CmdletBinding()] Param(
    [String]$NameSpace = 'root/cimv2',
    [Parameter(Mandatory=$True,Position=1)]
      [String]$Class,
    [Parameter(Mandatory=$False,Position=2)]
      [Regex]$KeyRegex,
    [Parameter(Mandatory=$False,Position=3)]
      [Regex]$ValueRegex,
    [Alias("Expression","Expr","Evaluation","Eval","E")]
      [ScriptBlock]$TestExpression,
    [Switch]$Dereference,
    [Switch]$Test,
    [Switch]$Assert
  )

  $WMIQuery = Get-WmiObject -NameSpace $NameSpace -Class $Class

  $Accepted  = Get-Command -Name Get-ObjectQuery | Select-Object -ExpandProperty Parameters

  $MyInvocation.MyCommand.ParameterSets[0].Parameters | %{
    if ( -not($Accepted.ContainsKey( $_.Name )) ) {
      $PSBoundParameters.Remove( $_.Name )  | Out-Null
    }
  }

  if ( $Test -or $Assert ) {
    $Local:ErrorActionPreference = 'SilentlyContinue'
  }

  if ( $TestExpression ) {
    $PSBoundParameters.Add( 'Dereference', $True) | Out-Null
  }

  $Query = Get-ObjectQuery @PSBoundParameters -InputObject $WMIQuery

  if ( $TestExpression ) {
    # TODO : This construct appears to be broken under PSv4
    $_ = $Query
    $NewSB = $TestExpression.GetNewClosure()
    $Query = $NewSB.Invoke()
  }

  if ( $Test -or $Assert ) {
    $QueryTest = ([Boolean]$Query)
    if ( $Assert -and -not($QueryTest) ) {
      $Local:ErrorActionPreference = 'STOP'
      $ErrMsg = "Assertion failed on ($($MyInvocation.MyCommand.Name)" +
                "-KeyRegex '$KeyRegex' -ValueRegex '$ValueRegex' " +
                "-Expr '$TestExpression')"
    }
    return $QueryTest
  }

  $Query
}

function Get-OS {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True,Position=1)]
      [String]$KeyRegex,
    [Parameter(Mandatory=$False,Position=2)]
      [String]$ValueRegex,
    [Alias("Expression","Expr","Evaluation","Eval","E")]
      [ScriptBlock]$TestExpression,
    [Switch]$Dereference,
    [Switch]$Assert,
    [Switch]$Test
  )

  Get-WMIQuery @PSBoundParameters -Class Win32_OperatingSystem
}

Function Get-OSArchitecture {
  param(
    [Switch] $Bitness,
    [Switch] $Short,
    [Switch] $Long
  )

  $OSArchitecture = (Gwmi -NameSpace "root\cimv2" -Class Win32_OperatingSystem).OSArchitecture
  $BitnessValue   = [Int32][String]([Regex]::Match( $OSArchitecture, '(\d+)' )).Groups[1]

  if ( $Bitness ) {
    $BitnessValue
  }
  elseif ( $Short ) {
    Switch ( $BitnessValue ) {
      64 { 'x64' }
      32 { 'x86' }
    }
  }
  elseif ( $Long ) {
    Switch ( $BitnessValue ) {
      64 { 'x86_64' }
      32 { 'x86' }
    }
  }
}

function Get-Cpu {
  [CmdletBinding()] Param(
    [Parameter(ParameterSetName='default',Mandatory=$True,Position=1)]
      [String]$KeyRegex,
    [Parameter(ParameterSetName='default',Mandatory=$False,Position=2)]
      [String]$ValueRegex,
    [Parameter(ParameterSetName='default')]
    [Alias("Expression","Expr","Evaluation","Eval","E")]
      [ScriptBlock]$TestExpression,
    [Parameter(ParameterSetName='default')]
      [Switch] $Dereference,
    [Parameter(ParameterSetName='default')]
      [Switch] $Assert,
    [Parameter(ParameterSetName='default')]
      [Switch] $Test,
    [Parameter(ParameterSetName='convenience')]
      [Switch] $Architecture,
    [Parameter(ParameterSetName='convenience')]
      [Switch] $Bitness
  )

  if ( $PSCmdLet.ParameterSetName -eq 'convenience' ) {
    if ( $Architecture ) {
      switch -regex ( (Get-Win32_Processor)[0].Architecture ) {
        0 { 'x86'     ; break; }
        1 { 'MIPS'    ; break; }
        2 { 'Alpha'   ; break; }
        3 { 'PowerPC' ; break; }
        4 { 'ARM'     ; break; }
        6 { 'IA64'    ; break; }
        9 { 'x64'     ; break; }
      }
    }
    elseif ( $Bitness ) {
      (Get-Win32_Processor)[0].AddressWidth
    }
  }
  else {
    Get-WMIQuery @PSBoundParameters -Class Win32_Processor
  }
}

function Invoke-SystemAudit {
  [CmdletBinding()] Param(
    [String]$logDir = (Join-Path "$Env:TEMP" "SystemAudit-$(Get-Date -UFormat %s)"),
    $remoteLogDir
  )

  Write-Verbose "Auditing System"
  Write-Verbose "  Logdir is $Logdir"
  mkdir $logDir -force > $Null

  Write-Verbose "Capturing $($Env:Windir)\Logs"
  mkdir (Join-Path $logDir "Windows\Logs") -Force > $Null
  mkdir (Join-Path $logDir "Windows\System32") -Force > $Null
  cp -ea 0 -Recurse -Force (Join-Path $Env:WINDIR "Logs") (Join-Path $logDir "Windows")
  cp -ea 0 -Recurse -Force (Join-Path $Env:WINDIR "Setup") (Join-Path $logDir "Windows")
  cp -ea 0 -Recurse -Force (Join-Path $Env:WINDIR "System32\Sysprep") (Join-Path $logDir "Windows\System32")

  Write-Verbose "Gathering environment env:"
  ls env: > "$logDir\ls+-env.log"

  Write-Verbose "Gathering Time Information"
  & w32tm -tz               > "$logDir\w32tm+-tz.log"
  & w32tm -query -status    > "$logDir\w32tm+-query+-status.log"
  & w32tm -query -source    > "$logDir\w32tm+-query+-source.log"
  & w32tm -query -peers     > "$logDir\w32tm+-query+-peers.log"

  Write-Verbose "Gathering information about network shares"
  net.exe share > "$logDir\net+share.log"
  net.exe use   > "$logDir\net+use.log"

  Write-Verbose "Gathering information about disk drives."
  gwmi Win32_DiskDrive                | fl * > "$LogDir\gwmi+Win32_DiskDrive.log"
  gwmi Win32_LogicalDrive -ea 0       | fl * > "$LogDir\gwmi+Win32_LogicalDrive.log"
  gwmi Win32_DiskQuota                | fl * > "$LogDir\gwmi+Win32_DiskQuota.log"
  gwmi Win32_MappedLogicalDrive -ea 0 | fl * > "$LogDir\gwmi+Win32_MappedLogicalDrive.log"
  gwmi Win32_CDROMDrive               | fl * > "$LogDir\gwmi+Win32_CDROMDrive.log"
  chkntfs.exe "$Env:SystemDrive"             > "$LogDir\chkntfs.exe+$($Env:SystemDrive -replace ':').log"
  Show-DiskUtilization -Factor 1GB    | fl * > "$LogDir\Show-DiskUtilization+-Factor+1GB.log"

  Write-Verbose "Gathering information about the operating system"
  (Get-Win32_OperatingSystem) | fl * > "$logDir\gwmi+Win32_OperatingSystem.log"
  (Get-Win32_ComputerSystem)  | fl * > "$logDir\gwmi+Win32_ComputerSystem.log"
  (Get-Win32_ComputerSystemProduct)  | fl * > "$logDir\gwmi+Win32_ComputerSystemProduct.log"
  gwmi Win32_PageFile        | fl * > "$logDir\gwmi+Win32_PageFile.log"
  Get-Uptime                 | fl * > "$logDir\Get-Uptime.log"

  Write-Verbose "Gathering information about the System Enclosure/BIOS"
  Get-Win32_Bios              | fl * > "$logDir\Get-Win32_BIOS.log"
  Get-Win32_SystemEnclosure   | fl * > "$logDir\Get-Win32_SystemEnclosure.log"
  Get-Win32_Processor         | fl * > "$logDir\Get-Win32_Processor.log"
  Gwmi Win32_PhysicalMemory   | fl * > "$logDir\Gwmi+Win32_PhysicalMemory.log"

  Write-Verbose "Gathering information about running processes"
  Get-TaskList                | fl * > "$logDir\Get-TaskList.log"
  Get-TaskList -Service       | fl * > "$logDir\Get-TaskList+-Service.log"
  Get-TaskList -ByModule      | fl * > "$logDir\Get-TaskList+-ByModule.log"

  Write-Verbose "Gathering information about drivers"
  Get-Driver -Extended        | fl * > "$logDir\Get-Driver+-Extended.log"
  Get-DriverVerifierSetting   | fl * > "$logDir\Get-DriverVerifierSetting.log"

  Write-Verbose "Gathering Windows Activation information"
  & cscript.exe (Join-Path $Env:SystemRoot "System32\slmgr.vbs") -dlv > "$logDir\slmgr+-dlv.log"
  & cscript.exe (Join-Path $Env:SystemRoot "System32\slmgr.vbs") -xpr > "$logDir\slmgr+-xpr.log"

  Write-Verbose "Gathering information about local users and groups"
  gwmi Win32_UserAccount | fl * > "$logDir\gwmi+Win32_UserAccount.log"
  gwmi Win32_Group | fl *       > "$logDir\gwmi+Win32_Group.log"

  Write-Verbose "Gathering information about startup commands"
  gwmi Win32_StartupCommand | fl *  > "$logDir\gwmi+Win32_StartupCommand.log"

  Write-Verbose "Collecting SystemInfo"
  systeminfo.exe 2>&1 > "$logDir\systeminfo.exe.log"
  Get-Sid           | fl * > "$logDir\Get-Sid.log"
  Get-MachineId     | fl * > "$logDir\Get-MachineId.log"
  Get-CurrentDomain | fl * > "$logDir\Get-CurrentDomain.log"
  Get-CurrentUser   | fl * > "$logDir\Get-CurrentUser.log"

  Write-Verbose "Running SysInternals log gathering tools"
  Initialize-SysInternals
  if ( gcm CoreInfo.exe -ea 0 ) {
    & CoreInfo.exe           > "$logDir\CoreInfo.txt"
  } else {
    Write-Warning "SysInternals CoreInfo.exe not available."
  }
  if ( gcm PsList.exe -ea 0 ) {
    & PsList.exe -x          > "$logDir\PsList+-x.txt"
    & PsList.exe -t          > "$logDir\PsList+-t.txt"
  }
  if ( gcm PsInfo.exe -ea 0 ) {
    & PsInfo.exe   -h -s -d  > "$logDir\PsInfo.txt"
  } else {
    Write-Warning "SysInternals PsInfo.exe not available."
  }
  if ( gcm NTFSInfo.exe -ea 0 ) {
    & NTFSInfo.exe $Env:SystemDrive      > "$logDir\NTFSInfo.txt"
  } else {
    Write-Warning "SysInternals NTFSInfo.exe not available."
  }
  if ( gcm ListDlls.exe -ea 0 ) {
    & ListDlls.exe -r        > "$logDir\ListDlls.exe+-r.log"
  }
  if ( gcm autorunsc.exe -ea 0 ) {
    & autorunsc.exe          > "$logDir\autorunsc.exe.log"
  }

  Write-Verbose "Gathering information about Installed Products and Hotfixes"
  gwmi Win32_Product | sort InstallDate -Descending > "$logDir\gwmi+Win32_Product.log"
  ls -R -Force "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | fl * > "$logDir\AddRemoveProgramsUninstallInfo.log"
  Get-HotFix | fl *            > "$logDir\Get-HotFix.log"
  Search-WindowsUpdate -History | fl * > "$logDir\Search-WindowsUpdate+-History.log"

  if ( gcm Get-DotNetFramework -ea 0 ) {
    Get-DotNetFramework | fl * > "$logDir\NTFSInfo.txt"
  }

  Write-Verbose "Gathering Windows and Network Services information"
  gwmi Win32_Service | fl *   > "$logDir\gwmi+Win32_Service.log"
  & netstat.exe -bona         > "$logDir\netstat+-bona.log"

  Write-Verbose "Gathering information about running processes"
  Get-Process | fl * > "$logDir\Get-Process.log"

  if (Import-Module ServerManager -ErrorAction 0) {
    Write-Verbose "Gathering information about Windows Features"
    Get-WindowsFeature | fl * > "$logDir\Get-WindowsFeature.log"
  }

  # try {
  #   # Fixme : This is really slow
  #   Write-Verbose "Gathering Windows Event Logs"
  #     gwmi Win32_NTLogEvent > "$logDir\Gwmi+Win32_NTLogEvent.log"
  #   #Get-EventLog -list | %{
  #     # Get-WinEvent -LogName $_.Log -ea 0 2> $null | fl * > "$logDir\Get-WinEvent.log"
  #     #}
  # } catch [Exception] {}

  Write-Verbose "Gathering information about scheduled tasks"
  Get-ScheduledTask | fl * > "$logDir\Get-ScheduledTask.log"

  Write-Verbose "Gather information about roles and features"
  dism.exe -english -online -get-features >  "$logdir\dism.exe+-english+-online+-get-features.log"
  if ( gmo -ListAvailable ServerManager ) {
    ipmo ServerManager
    Get-WindowsFeatures | fl *            >  "$logDir\Get-WindowsFeatures.log"
  }

  Write-Verbose "Gathering information about PowerShell Drives"
  Get-PSDrive | fl * > "$logDir\Get-PSDrive.log"

  Write-Verbose "Gathering information about PowerShell"
  Write-Verbose "   PSProviders"
  Get-PSProvider -Verbose | fl * > "$logDir\Get-PSProvider.log"
  Write-Verbose "   PSSnapins"
  Get-PSSnapin -Verbose   | fl * > "$logDir\Get-PSSnapin.log"
  Write-Verbose "   Modules"
  Get-Module -Verbose -All | fl * > "$logDir\Get-Module+-All.log"
  Get-Module -Verbose -ListAvailable | fl * > "$logDir\Get-Module+-ListAvailable.log"

  Write-Verbose "Gathering power profile information (via powercfg)"
  if (gcm "powercfg" 2>&1 | Out-Null) {
    & powercfg.exe -l | ?{ $_ -imatch "Power Scheme GUID" } | %{ $_ -imatch "([a-f0-9\-]{36})" |
        Out-Null; $matches[1] } | %{ powercfg.exe -Q $_ }
  }

  Write-Verbose "Gathering sysprep logs"
  if (Test-Path($sysprepLogDir = Join-Path $Env:SystemRoot "System32\SysPrep\Panther")) {
    mkdir -Force ($sysprepLogDirTarget = Join-Path $logDir 'Sysprep\Panther') > $Null
    & xcopy /v /e /s /Y $sysprepLogDir $sysprepLogDirTarget
  }

  Write-Verbose "Gathering netsh information"
  & netsh.exe advfirewall consec show rule name=all > "$logDir\netsh+advfirewall+consec+show+rule+name=all.log"
  & netsh.exe advfirewall dump            > "$logDir\netsh.exe+advfirewall+dump.log"
  & netsh.exe advfirewall export            "$logDir\netsh.exe+advfirewall+export.log" # the missing redirect is intentional
  & netsh.exe advfirewall firewall dump   > "$logDir\netsh.exe+advfirewall+firewall+dump.log"
  & netsh.exe advfirewall firewall show rule name=all > "$logDir\netsh.exe+advfirewall+firewall+show+rule+name=all.log"
  & netsh.exe advfirewall monitor dump    > "$logDir\netsh.exe+advfirewall+monitor.log"
  & netsh.exe advfirewall show all        > "$logDir\netsh.exe+advfirewall+show+all.log"
  & netsh.exe advfirewall show global     > "$logDir\netsh.exe+advfirewall+show+global.log"
  & netsh.exe bridge dump                 > "$logDir\netsh.exe+bridge+dump.log"
  & netsh.exe dump                        > "$logDir\netsh.exe+dump.log"
  & netsh.exe firewall show state         > "$logDir\netsh.exe+firewall+show+state.log"
  & netsh.exe http dump                   > "$logDir\netsh.exe+http+dump.log"
  & netsh.exe interface dump              > "$logDir\netsh.exe+interface+dump.log"
  & netsh.exe ipsec dump                  > "$logDir\netsh.exe+ipsec+dump.log"
  & netsh.exe lan show interfaces         > "$logDir\netsh.exe+lan+show+interfaces.log"
  & netsh.exe lan show interfaces         > "$logDir\netsh.exe+lan+show+interfaces.log"
  & netsh.exe lan show profiles           > "$logDir\netsh.exe+lan+show+profiles.log"
  & netsh.exe lan show settings           > "$logDir\netsh.exe+lan+show+settings.log"
  & netsh.exe nap dump                    > "$logDir\netsh.exe+nap+dump.log"
  & netsh.exe netio dump                  > "$logDir\netsh.exe+netio+dump.log"
  & netsh.exe rpc dump                    > "$logDir\netsh.exe+rpc+dump.log"
  & netsh.exe winhttp dump                > "$logDir\netsh.exe+winhttp+dump.log"
  & netsh.exe winsock dump                > "$logDir\netsh.exe+winsock+dump.log"
  & netsh.exe interface ipv6 show /? | ?{ $_ -imatch "^show" } | %{
    $command = ($_ -split '\s')[1]
    $filename = ((echo netsh interface ipv6 show $command) -join "+") + ".log"
    & netsh.exe interface ipv6 show $command > "$logDir\$filename"
  }
  & netsh interface ipv4 show /? | ?{ $_ -imatch "^show" } | %{
    $command = ($_ -split '\s')[1]
    $filename = ((echo netsh interface ipv4 show $command) -join "+") + ".log"
    & netsh.exe interfac ipv4 show $command > "$logDir\$filename"
  }

  Write-Verbose "Gathering IPGlobal Properties"
  Get-IPGlobalProperties          | fl * > "$logDir\Get-IPGlobalProperties.log"

  Write-Verbose "Gathering Information about WMI state"
  Gwmi -List -EnableAllPrivileges | fl * > "$logDir\Get-WMIObject+-List+-EnableAllPrivileges.log"
  Get-WMIClassEnumeration         | fl * > "$logDir\Get-WMIClassEnumeration.log"

  Write-Verbose "Gathering Information about User and Groups"
  Get-UserProfile                 | fl * > "$logDir\Get-UserProfile.log"
  Get-User                        | fl * > "$logDir\Get-User.log"
  Get-Group                       | fl * > "$logDir\Get-Group.log"
  net.exe accounts                       > "$logDir\net.exe+accounts.log"
  net.exe user                           > "$logDir\net.exe+user.log"
  net.exe group                          > "$logDir\net.exe+group.log"
  net.exe config                         > "$logDir\net.exe+config.log"
  net.exe file                           > "$logDir\net.exe+file.log"
  net.exe localgroup                     > "$logDir\net.exe+localgroup.log"
  net.exe session                        > "$logDir\net.exe+session.log"
  net.exe share                          > "$logDir\net.exe+share.log"
  net.exe statistics                     > "$logDir\net.exe+statistics.log"
  net.exe time                           > "$logDir\net.exe+time.log"
  net.exe use                            > "$logDir\net.exe+use.log"
  net.exe user                           > "$logDir\net.exe+user.log"
  net.exe view                           > "$logDir\net.exe+view.log"
  getmac.exe                             > "$logDir\getmac.exe.log"
  netstat -ban                           > "$logDir\netstat.exe+-ban.log"
  arp.exe -an                            > "$logDir\arp.exe+-an.log"

  Write-Verbose "Gathering Information about powershell"
  $PSVersionTable                 | fl * > "$logDir\PSVersionTable.log"
  $PSCulture                      | fl * > "$logDir\PSCulture.log"
  $Host                           | fl * > "$logDir\Host.log"
  $Host.UI.RawUI                  | fl * > "$logDir\Host.UI.RawUI.log"
  $PSSessionOption                | fl * > "$logDir\PSSessionOption.log"
  Get-Host                        | fl * > "$logDir\Get-Host.log"
}

function Get-CurrentDomain {
  [CmdletBinding()] Param()
  $Domain = New-Object -TypeName PSObject

  $DomainRole = switch -Regex ( (Get-Win32_ComputerSystem).DomainRole ) {
    0   { @(0x0, 'Standalone Workstation')    ; break; }
    1   { @(0x1, 'Member Workstation')        ; break; }
    2   { @(0x2, 'Standalone Server')         ; break; }
    3   { @(0x3, 'Member Server')             ; break; }
    4   { @(0x4, 'Backup Domain Controller')  ; break; }
    5   { @(0x5, 'Primary Domain Controller') ; break; }
  }

  $Domain | Add-Member -PassThru NoteProperty DomainName      (Get-Win32_ComputerSystem).Domain       |
            Add-Member -PassThru NoteProperty UserDomainName  ([Environment]::UserDomainName)   |
            Add-Member -PassThru NoteProperty PartOfDomain    (Get-Win32_ComputerSystem).PartOfDomain |
            Add-Member -PassThru NoteProperty LogonServer     $Env:LogonServer                  |
            Add-Member -PassThru NoteProperty UserDomain      $Env:UserDomain                   |
            Add-Member -PassThru NoteProperty UserDnsDomain   $Env:UserDnsDomain                |
            Add-Member -PassThru NoteProperty DomainRole      $DomainRole[0]                    |
            Add-Member           NoteProperty DomainRoleName  $DomainRole[1]

  if ( (Get-Win32_ComputerSystem).PartOfDomain ) {
    try {
      $CurrentDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
      $Currentdomain | gm -MemberType Property  | %{
        $Domain | Add-Member NoteProperty $_.Name $CurrentDomain.($_.Name) -force
      }
    } catch {}

    try {
      $NTDomain = Get-WmiObject -Query `
                  "Select * from Win32_NTDomain WHERE DomainName='$([Environment]::UserDomainName)'" |
                    Select Domain*,Dns*,DC*,DS*,Client*,Desc*,Install*,Name*,Primary*
      $NTDomain | gm -Membertype NoteProperty | %{
        $Domain | Add-Member NoteProperty $_.Name $NTDomain.($_.Name) -force
      }
    } catch {
      Write-Warning " Error adding object property ; $_"
    }

    try {
      $LDAPDirectoryEntry = Search-LDAP -ObjectClass Domain | ?{ [Guid](($_.ObjectGuid)[0]) -eq [Guid]($Domain.DomainGuid) }
      $Domain | Add-Member NoteProperty LDAPDirectoryEntry $LDAPDirectoryEntry
    } catch {
      Throw "Error performing LDAP query : $_"
    }
  }
  $Domain
}

function Get-Group {
  [CmdletBinding()] Param ()
  Gwmi -NameSpace "root\cimv2" -Class Win32_Group
}

function Get-User {
  [CmdletBinding()] Param ( [Switch]$Anonymous,
    [Switch] $Current,
    [Switch] $LocalAccounts,
    [Switch] $All = $True,
    [Regex]$UserNameRegex
  )

  $Collection = @()

  if ( $Current ) {
    $Collection += [Security.Principal.WindowsIdentity]::GetCurrent()
  }
  elseif ( $Anonymous ) {
    $Collection += [Security.Principal.WindowsIdentity]::GetAnonymous()
  }
  elseif ( $UserNameRegex ) {
    $Collection += Get-User | ?{ $_.Name -imatch "$UserNameRegex" }
  }
  elseif ( $LocalAccounts ) {
    Gwmi -NameSpace "root\cimv2" -Class Win32_UserAccount -Filter "LocalAccount='$True'" | %{
      $Collection += $_
    }
  }
  elseif ( $All ) {
    Gwmi -NameSpace "root\cimv2" -Class Win32_UserAccount | %{
      $Collection += $_
    }
  }

  $Collection
}

function Get-CurrentUser {
  [CmdletBinding()] Param ( $UserName = $Env:UserName
  )

  $WindowsSecurityPrincipal = if ($username -eq $Env:USERNAME) {
    [Security.Principal.WindowsIdentity]::GetCurrent()
  }
  else {
    [Security.Principal.WindowsIdentity]"$username"
   i$Id = New-Object System.Security.Principal.NTAccount($Username)
   ` iId = N`ew-Object iystem.Security.Principal.NTAccount($Username)
  }

  $ResolvedSecurityPrincipal = New-Object Security.Principal.WindowsPrincipal ( $WindowsSecurityPrincipal )

  # Define user object as copy of $ResolvedSecurityPrincipal.identity
  $user = $ResolvedSecurityPrincipal.Identity
  ($userNetBIOSDomain, $userName) = (($ResolvedSecurityPrincipal.Identity.Name) -split "\\")

  $user = Add-Member -InputObject $user -PassThru -Force -MemberType NoteProperty -Name "UserName"          -Value $userName
  $user = Add-Member -InputObject $user -PassThru -Force -MemberType NoteProperty -Name "UserNetBIOSDomain" -Value $userNetBIOSDomain
  $user = Add-Member -InputObject $user -PassThru -Force -MemberType NoteProperty -Name "AccountSID"        -Value $ResolvedSecurityPrincipal.Identity.User.Value
  $user = Add-Member -InputObject $user -PassThru -Force -MemberType NoteProperty -Name "AccountDomainSID"  -Value $ResolvedSecurityPrincipal.Identity.User.AccountDomainSid

  $user = Add-Member -InputObject $user -PassThru -Force -MemberType NoteProperty `
            -Name "GroupNames" `
            -Value ( $user.Groups | %{
                      $sid = $_.Value
                      $sid = New-Object System.Security.Principal.SecurityIdentifier($sid)
                      ($sid.Translate([System.Security.Principal.NTAccount])).Value
                    } )

  # Populate the Is<Principal> attributes e.g. IsAdministrator, IsGuest, IsPowerUser, etc
  [Security.Principal.WindowsBuiltInRole].GetFields() | %{
    try {
      $user | Add-Member NoteProperty "Is$($_.Name)" `
              $ResolvedSecurityPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::($_.Name))
    } catch {}
  }

  # Pointer to LDAP directory entry information
  $LDAPDirectoryEntry = if ( (Get-Win32_ComputerSystem).PartOfDomain ) {
    try {
      Search-LDAPUser -SamAccountName $Env:USERNAME
    } catch {
      Write-Error "Error looking up user ($Env:Username) in LDAP : $_"
    }
  }
  else {
    $Null
  }

  $user | Add-Member NoteProperty LDAPDirectoryEntry $LDAPDirectoryEntry
  $user
}

function Get-AdsiObject {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)] [String] $SearchString
  )
  [ADSI]$SearchString
}

function Search-DistginguishedName {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)]
      [String] $DN,
    [Switch] $FindAll = $False
  )

  if ($DN -notmatch '^[^:]+:\/\/','') {
    $DN = 'LDAP://{0}' -f $DN
  }
  Search-LDAP -AdsPath $DN -FindAll:$FindAll
}

function Search-LDAPUser {
  [CmdletBinding()] Param(
    [String] $SamAccountName='*',
    [String] $AdsPath=("LDAP://{0}" -f (($Env:USERDNSDOMAIN -split '\.' | %{ $_="DC=$_"; $_ }) -join ",")),
    [String] $LdapFilter="(&(objectClass=user)(samAccountName=$SamAccountName))"
  )

  Search-LDAP -AdsPath $AdsPath -LdapFilter $LdapFilter
}

function Search-LDAP {
  [CmdletBinding()] Param(
    [String] $ObjectClass='*',
    [String] $ObjectCategory='*',
    [String] $AdsPath=("LDAP://{0}" -f (($Env:USERDNSDOMAIN -split '\.' | %{ $_="DC=$_"; $_ }) -join ",")),
    [String] $LdapFilter="(&(objectCategory=$objectCategory)(objectClass=$ObjectClass))",
    [Switch] $FindAll = $True
  )

  if ( $DirectorySearcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]$AdsPath) ){
    $DirectorySearcher.Filter=$LdapFilter

    $SearchResult = if ( $FindAll ) {
      $DirectorySearcher.FindAll()
    }
    else {
      $DirectorySearcher.FindOne()
    }

    $SearchResult | %{
      $Hash = [HashTable]($_.Properties)
      $Result = New-Object PSObject
      $Hash.Keys | %{
        $Result | Add-Member NoteProperty $_ $Hash.$_
      }
      $Result
    }
  }

}

function Set-ADUserPassword {
  [CmdletBinding()] Param(
    [string] $username,
    [string] $password
  )

  $userDN = (Get-CurrentUser).LDAPDirectoryEntry.distinguishedName
  if ( $userDN ) {
    try {
      $ADUser = [ADSI]"LDAP://$userDN"
      $ADUser.psbase.invoke("SetPassword",$password)
      $ADUser.psbase.CommitChanges()
    } catch [Exception] {
      Write-Error "Unable to set password for '$username' : $_ [$error]"
    }
  }
  else {
    Write-Error "Unable to lookup distinguished name for '$username'"
  }
}

function Test-UserIsElevated {
  [CmdletBinding()] Param(
    [Switch]$Assert
  )
  $SecurityPrincipal  = New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())
  $IsAdministrator    = $SecurityPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

  if ( $Assert -and -not($IsAdministrator) ) { throw "User ($Principal) is not elevated."  }

  return $IsElevated
}


# ADS_USER_FLAG_ENUM enumeration
# http://msdn.microsoft.com/en-us/library/windows/desktop/aa772300(v=vs.85).aspx
$ADS_USER_FLAG = @{
  ADS_UF_SCRIPT                                  = 0x0000001;  # 1,        //
  ADS_UF_ACCOUNTDISABLE                          = 0x0000002;  # 2,        //
  ADS_UF_HOMEDIR_REQUIRED                        = 0x0000008;  # 8,        //
  ADS_UF_LOCKOUT                                 = 0x0000010;  # 16,       //
  ADS_UF_PASSWD_NOTREQD                          = 0x0000020;  # 32,       //
  ADS_UF_PASSWD_CANT_CHANGE                      = 0x0000040;  # 64,       //
  ADS_UF_ENCRYPTED_TEXT_PASSWORD_ALLOWED         = 0x0000080;  # 128,      //
  ADS_UF_TEMP_DUPLICATE_ACCOUNT                  = 0x0000100;  # 256,      //
  ADS_UF_NORMAL_ACCOUNT                          = 0x0000200;  # 512,      //
  ADS_UF_INTERDOMAIN_TRUST_ACCOUNT               = 0x0000800;  # 2048,     //
  ADS_UF_WORKSTATION_TRUST_ACCOUNT               = 0x0001000;  # 4096,     //
  ADS_UF_SERVER_TRUST_ACCOUNT                    = 0x0002000;  # 8192,     //
  ADS_UF_DONT_EXPIRE_PASSWD                      = 0x0010000;  # 65536,    //
  ADS_UF_MNS_LOGON_ACCOUNT                       = 0x0020000;  # 131072,   //
  ADS_UF_SMARTCARD_REQUIRED                      = 0x0040000;  # 262144,   //
  ADS_UF_TRUSTED_FOR_DELEGATION                  = 0x0080000;  # 524288,   //
  ADS_UF_NOT_DELEGATED                           = 0x0100000;  # 1048576,  //
  ADS_UF_USE_DES_KEY_ONLY                        = 0x0200000;  # 2097152,  //
  ADS_UF_DONT_REQUIRE_PREAUTH                    = 0x0400000;  # 4194304,  //
  ADS_UF_PASSWORD_EXPIRED                        = 0x0800000;  # 8388608,  //
  ADS_UF_TRUSTED_TO_AUTHENTICATE_FOR_DELEGATION  = 0x1000000;  # 16777216  //
};

$ADS_USER_FLAG_VAL = @{};

$ADS_USER_FLAG.keys | %{
  $ADS_USER_FLAG_VAL.($ADS_USER_FLAG.$_) = $_
};

function Set-UserFlags {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)]
      [String]$UserName,
    [Parameter(Mandatory=$True)]
      [Int]$Flag,
    [Parameter(Mandatory=$False)]
      [Switch]$Unset
  )

  $FuncName = $MyInvocation.MyCommand.Name
  try {
    $UserAccount = [ADSI]"WinNT://$Env:COMPUTERNAME/$userName,user"
    $OldUserFlagsValue = $UserAccount.UserFlags.Value
    Write-Verbose "$FuncName : Adjusting flag '$($ADS_USER_FLAG_VAL.$Flag)' ($Flag=$('0x{0:X}' -f $Flag)) on '$Username' ($OldUserFlagsValue)."
    $NewFlags = if ( $Unset ) {
      if ( ($UserAccount.UserFlags[0] -band $flag) -ne 0 ) {
        $UserAccount.UserFlags[0] -bxor $flag  # toggle
      } else {
        $UserAccount.UserFlags[0]
      }
    } else {
      $UserAccount.UserFlags[0] -bor $flag
    }
    $NewUserFlagsValue = $UserAccount.UserFlags.Value
    $UserAccount.InvokeSet( "UserFlags", $NewFlags )
    $UserAccount.CommitChanges()
    Write-Verbose "   Changed user flags ($OldUserFlagsValue ? $Flag = $NewFlags), Unset=$Unset."
  }
  catch { throw "Error setting user account flags : $_" }
}

function New-LocalAdministrativeUser {
  [CmdletBinding()] Param (
    [String] $UserName = 'Administrator',
    [String] $Password,
    [Switch] $AccountDisabled = $False,
    [Switch] $PasswordNeverExpires = $True,
    [Switch] $PasswordNotRequired = $False
  )

  Write-Verbose "Creating and enabling administrative account '$UserName'"

  $localComputer = [ADSI] "WinNT://$Env:COMPUTERNAME"
  try {
    Write-Verbose "Creating user '$username'"
    $UserAccount = $localComputer.Create("User", $username)
    $UserAccount.SetInfo()
  } catch [Exception] {
    if ( -not($_ -imatch "already exists") ) {
      Write-Error "Error creating user : $_"
    } else {
      Write-Verbose "  Account already exists."
    }
  }

  try {
    $UserAccount  = [ADSI]"WinNT://$Env:ComputerName/$username"
    $groupAccount = [ADSI]"WinNT://$Env:ComputerName/Administrators"
    Write-Verbose "Adding '$username' ($($UserAccount.Path)) to the 'Administrators' ($($groupAccount.Path)) local group."
    $groupAccount.PSBase.Invoke("Add",$UserAccount.PSBase.Path)
  } catch [Exception] {
    if ( -not($_ -imatch "already a member") ) {
      Write-Host -ForegroundColor magenta "Error adding user to group: $_"
    } else {
      Write-Verbose "  Account is already a member."
    }
  }

  try {
    Write-Verbose "  Setting password "
    $UserAccount.SetPassword($Password)
  } catch [Exception] {
    Throw "Error setting user password : $_"
  }

  try {
    Set-UserFlags -User $UserName -Flag $ADS_USER_FLAG.ADS_UF_ACCOUNTDISABLE      -Unset:([Boolean]([Boolean]($AccountDisabled) -bxor $True))
    Set-UserFlags -User $UserName -Flag $ADS_USER_FLAG.ADS_UF_PASSWD_NOTREQD      -Unset:([Boolean]([Boolean]($PasswordNotRequired) -bxor $True))
    Set-UserFlags -User $UserName -Flag $ADS_USER_FLAG.ADS_UF_DONT_EXPIRE_PASSWD  -Unset:([Boolean]([Boolean]($PasswordNeverExpires) -bxor $True))
    $UserAccount.CommitChanges()
  } catch [Exception] {
    Throw "Error setting user account flags : $_"
  }

  Get-NetUser -Username $Username
}

function Get-NetUser {
  [CmdletBinding()] Param (
    [Parameter(Mandatory=$False)]
      [String] $Username
  )

  if ( -not($Username) ) {
    $NetUsers = net.exe user | ?{
      ($_ -notmatch '^(?:User accounts|--{2,}|The command)') -and ($_)
    } | %{
      $_ -split '\s{2,}' | ?{$_ -imatch '\S'} | %{
        Get-NetUser -Username $_
      }
    }
    return $NetUsers
  }

  $UserFlag = New-Object PSObject
  $TextInfo = (Get-Culture).TextInfo

  $lines = net.exe user $username 2>&1 | ?{
    $_ -and ($_ -notmatch 'The command completed successfully.')
  }

  if ( $lines -imatch '^More help is available' ) {
    $ErrMsg = $lines | ?{ $_ } | ?{ $_ -notmatch '^More help is available' }
    Throw "Error processing 'net user $Username' : $ErrMsg"
  }

  ForEach ($Line in $Lines) {
    ([String]$Key, $Value) = $Line -split '\s\s\s+'

    $Provider = New-Object System.Globalization.CultureInfo $Host.CurrentCulture.Name

    $Value = Switch -Regex ($Value) {
      '^Yes$' { $True;  break; }
      '^No$'  { $False; break; }
      ',|\*'  { $Value -split ',|\*' | %{ $_ -replace '^\s+|\s+$','' } | ?{$_}; break; }
      '\d{2}:\d{2}:\d{2}' { [DateTime]::ParseExact($_, 'dd/MM/yyyy HH:mm:ss', $Provider); break; }
      '^Never$' { [DateTime]::MaxValue; break; }
      .*      { $Value }
    }

    if ( $Key ) {
      $Key = (($Key -split '\s+' | %{ $_ = $_ -replace "/|\'", ''; $TextInfo.ToTitleCase($_) }) -join '')
      $UserFlag | Add-Member NoteProperty $Key $Value
      $LastKey = $Key
    }
    else {
      $UserFlag | Add-Member NoteProperty $LastKey (@($UserFlag.$LastKey, $Value) | %{ $_ }) -Force
    }
  }

  $UserFlag
}

function Get-UserProfile {
  [CmdletBinding()] Param() gwmi Win32_UserProfile | Select -ExcludeProperty ClassPath,Path,*Options,*Properties,*Scope -Property '[A-Z]*' | %{
    $up = $_
    $UserSid = New-Object System.Security.Principal.SecurityIdentifier($_.SID)
    $UserName = $UserSid.Translate([System.Security.Principal.NTAccount])
    $up | Add-Member NoteProperty UserName $UserName
    $up
  }
}

function Remove-UserProfile {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
      [PSCustomObject]$profile
  )
  Begin {}
  Process {
    $candidate = Gwmi -query ("select * from win32_userprofile where SID='" + $Profile.SID + "'")
    try {
      Write-Verbose "Attempting to delete profile for user $($Profile.UserName) ($($Profile.SID))"
      $candidate.Delete()
      Write-Verbose "  Profile for $($Profile.UserName) deleted successfully."
    } catch {
      $_ | Write-Warning
    }
  }
  End {}
}

function Get-DirectorySize {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
      [String]$Path,
    [String]$Name,
    [String]$Filter,
    [String[]]$Include,
    [String[]]$Exclude,
    [Switch]$Recurse,
    [Switch]$Force
  )
  ls @PSBoundParameters | Measure-Object -Property Length -Min -Max -Ave -Sum
}

function Show-PageFile {
  [CmdletBinding()] Param() Get-PageFile | Select '[A-Za-z]*' `
    -ExcludeProperty Scope,Path,Options,ClassPath,SystemProperties,Qualifiers,Site,Container | %{
      if ($PageFile = ls -Force $_.Name -ea 0) {
        $_ | Add-Member NoteProperty CurrentSize ($PageFile.Length / 0x100000)
      } else {
        $_ | Add-Member NoteProperty CurrentSize $Null
      }
      $_
    }
}

function Set-AutomaticManagedPagefile {
  [CmdletBinding()] Param(
    [Switch]$Disabled
  )
  try {
    $Win32_ComputerSystem = Get-Win32_ComputerSystem
    $Win32_ComputerSystem.AutomaticManagedPagefile = if ($Disabled) { $False } else { $True }
    $Win32_ComputerSystem.Put() | Write-Verbose
  } catch {
    $_ | Write-Warning
  }
}

function Enable-AutomaticManagedPagefile {
  [CmdletBinding()] Param() Set-AutomaticManagedPagefile
}

function Disable-AutomaticManagedPagefile {
  [CmdletBinding()] Param() Set-AutomaticManagedPagefile -Disabled
}

function Set-ClearPageFileAtShutdown {
  [CmdletBinding()] Param(
    [Switch]$Disabled
  )
  Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name ClearPageFileAtShutdown -Value ($_=if ($Disabled){0}else{1}) -Verbose:$VerbosePreference
}

function Enable-ClearPageFileAtShutdown {
  [CmdletBinding()] Param() Set-ClearPageFileAtShutdown -Verbose:$VerbosePreference
}

function Disable-ClearPageFileAtShutdown {
  [CmdletBinding()] Param()
  Set-ClearPageFileAtShutdown -Disabled -Verbose:$VerbosePreference
}

function Show-PageFileProperties {
  [CmdletBinding()] Param()
  $amp = $Null
  try {
    $amp = (Get-Win32_ComputerSystem).AutomaticManagedPageFile
  } catch {}
  get-itemproperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' |
    select *Page* | %{
      $_ | Add-Member NoteProperty AutomaticManagedPageFile $amp
      $_
    }
}

function Get-PageFile {
  [CmdletBinding()] Param()
  Gwmi -Class Win32_PageFileSetting -EnableAllPrivileges
}

function Set-PageFile {
  [CmdletBinding()] Param(
    [parameter(Mandatory = $True)]
    [Alias("name")]
      [String]$PageFile,
    [Int32]$InitialSize = 0x400,
    [Int32]$MaximumSize = ((Get-Win32_ComputerSystem).TotalPhysicalMemory/1MB)
  )

  $PageFileLeaf = Split-Path $PageFile -Leaf
  $query = "Select * from Win32_PageFileSetting where name like '%$PageFileLeaf%'"
  Write-Verbose "Gwmi -query `"$query`""
  if ($pf = Gwmi -Query $query) {
    Write-Verbose "  Found $pf"
    $pf.InitialSize = $InitialSize;
    try {
      $pf.Put() | Write-Verbose
    } catch {}
    $pf.MaximumSize = $MaximumSize;
    try {
      $pf.Put() | Write-Verbose
    } catch {}
  }
  else {
    New-PageFile @PSBoundParameters
  }
  # Gwmi -Class Win32_PageFileSetting | %{}
}

function New-PageFile {
  [CmdletBinding()] Param(
    [parameter(Mandatory = $True)] [alias("name")]
      [String]$PageFile,
    [Int32]$InitialSize = 0x400,
    [Int32]$MaximumSize = ((Get-Win32_ComputerSystem).TotalPhysicalMemory/1MB)
  )
  Write-Verbose "Creating $PageFile"
  $hash = @{
    name=$PageFile;
    InitialSize=$InitialSize;
    MaximumSize=$MaximumSize;
  }
  Set-WMIInstance -Class Win32_PageFileSetting -Arguments @{Name=$PageFile} | Write-Verbose
  Set-PageFile @hash
}

function Remove-PageFile {
  [CmdletBinding()] Param (
    [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
      $PageFile
  )
  Process {
    Write-Verbose "Deleting $PageFile"
    try {
      $PageFile.Delete()
      Write-Verbose "  Deleted successfully."
    } catch {
      throw
    }
  }
}

function Measure-EventLogEvents {
  # TODO : Optimization required as it times out for being too slow.
  [CmdletBinding()] Param()
  gwmi Win32_NTLogEvent | Group-Object -Property LogFile,Type | %{
    $out = New-Object PSObject
    $out |
      Add-Member NoteProperty Name  $_.Name   -PassThru |
      Add-Member NoteProperty Count $_.Count
    $out
  }
}

function Get-Sid {
  [CmdletBinding()] Param(
    [String] $Username = $Env:UserName,
    [String] $SID
  )

  if ( $SID ) {
    try {
      $ID = New-Object System.Security.Principal.SecurityIdentifier($SID)
      $ID.Translate( [System.Security.Principal.NTAccount] )
    } catch {
      Throw "Unable to resolve Username for SID '$SID' : $_"
    }
  }
  elseif ( $Username ) {
    try {
      $Id = New-Object System.Security.Principal.NTAccount($Username)
      $Id.Translate( [System.Security.Principal.SecurityIdentifier] )
    } catch {
      Throw "Unable to resolve SID for Username '$Username' : $_"
    }
  }
}

function Set-ComputerDescription {
  [CmdletBinding()] Param(
    [String] $Description
  )
  reg.exe add 'HKLM\SYSTEM\CurrentControlSet\services\LanmanServer\Parameters' /f /v srvcomment /t REG_SZ /d $Description | Write-Verbose
}

function Get-MachineId {
  [CmdletBinding()] Param(
    [Switch] $Extended
  )

  $this = New-Object PSObject

  # The following two UUIDs are unique per machine
  (Get-Win32_ComputerSystemProduct) | Select-Object UUID, IdentifyingNumber | %{
    $this | Add-Member NoteProperty UUID              ([Guid]($_.UUID))     -PassThru |
            Add-Member NoteProperty IdentifyingNumber $_.IdentifyingNumber
  }

  # BIOS Serial Number is unique per HVM container - byteswapped value of the above
  $this | Add-Member NoteProperty SerialNumber  (Get-Win32_Bios | Select -Expand SerialNumber)
  $this | Add-Member NoteProperty ProcessorId   (Get-Win32_Processor)[0].ProcessorId

  # ComputerSid
  $this | Add-Member NoteProperty AccountDomainSid (Get-Sid).AccountDomainSid.ToString()

  $IPGP = Get-IPGlobalProperties
  $This | Add-Member NoteProperty MacAddresses (($IPGP.MacAddresses | sort) -join '|')
  $This | Add-Member NoteProperty FQDN     $IPGP.FQDN
  $This | Add-Member NoteProperty Hostname $IPGP.HostName

  $LanmanParametersPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'

  $srvcomment = $Null
  try {
    $srvcomment = ( gp $LanmanParametersPath | Select -Expand srvcomment )
  } catch {}
  $This | Add-Member NoteProperty ComputerDescription $srvcomment

  $LanmanServerGuid = ( gp $LanmanParametersPath | Select -Expand guid )
  $This | Add-Member NoteProperty LanmanServerGuid `
          ([Guid](($LanmanServerGuid | %{ $_.ToString('x2') }) -join ''))

  $DNSDomain = $Null
  try {
    $DNSDomain  = ( gp $LanmanParametersPath | Select -Expand 'Domain' )
  } catch {}
  $This | Add-Member NoteProperty PrimaryDnsDomain $DNSDomain

  $NVDomain = $Null
  try {
    $NVDomain = ( gp $LanmanParametersPath | Select -Expand 'NV Domain' )
  } catch {}
  $This | Add-Member NoteProperty PrimaryDnsSuffix $NVDomain

  # This is a burned-in value and should be unique to all machines derived
  # from a Master/Golden Image
  $MachineGuid = $Null
  try {
    $MachineGuid = [Guid](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography").MachineGuid
  } catch { }
  $this | Add-Member NoteProperty MachineGuid $MachineGuid

  if ( $Extended ) {
    $This | Add-Member NoteProperty AdsiGuid  ([Guid]([ADSI]"WinNT://${Env:ComputerName}").Guid)
  }

  return $this
}

# http://poshcode.org/2958
function Set-PrimaryDnsSuffix {
  [CmdletBinding()] Param ( [String] $Suffix
  )

  # http://msdn.microsoft.com/en-us/library/ms724224(v=vs.85).aspx
  $ComputerNamePhysicalDnsDomain = 6

  Add-Type -TypeDefinition @"
  using System;
  using System.Runtime.InteropServices;

  namespace ComputerSystem {
    public class Identification {
      [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
      static extern bool SetComputerNameEx(int NameType, string lpBuffer);

      public static bool SetPrimaryDnsSuffix(string suffix) {
        try {
          return SetComputerNameEx($ComputerNamePhysicalDnsDomain, suffix);
        }
        catch (Exception) {
          return false;
        }
      }
    }
  }
"@

[ComputerSystem.Identification]::SetPrimaryDnsSuffix($Suffix)

}

function Get-IPGlobalProperties {
  [CmdletBinding()] Param(
    [Switch] $FQDN,
    [Switch] $Hostname,
    [Switch] $Domain,
    [Switch] $NodeType,
    [Switch] $DhcpScopeName,
    [Switch] $IsWinsProxy,
    [Switch] $IsPartOfDomain,
    [Switch] $DomainRole,
    [Switch] $WorkGroup,
    [Switch] $MacAddresses,
    [Switch] $IPAddresses,
    [Switch] $IsNetworkAvailable,
    [Switch] $DefaultIPGateways
  )

  $IPGlobalProperties = New-Object -TypeName PSObject

  $ipProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()

  Add-Member -InputObject $IPGlobalProperties -MemberType NoteProperty -Name 'FQDN'                 -Value ( $_ =
      if ( $ipProperties.DomainName ) {
      "{0}.{1}" -f $ipProperties.HostName, $ipProperties.DomainName
      } else {
      $Null
      })
  Add-Member -InputObject $IPGlobalProperties -MemberType NoteProperty -Name 'HostName'             -Value ($_ =
      $ipProperties.HostName
      )
  Add-Member -InputObject $IPGlobalProperties -MemberType NoteProperty -Name 'IsPartOfDomain'       -Value ($_ =
      [Boolean]((Get-Win32_ComputerSystem).PartOfDomain)
      )
  Add-Member -InputObject $IPGlobalProperties -MemberType NoteProperty -Name 'DomainName'           -Value ($_ =
      if ($DomainName = $ipProperties.DomainName) { $DomainName } else { (Get-Win32_ComputerSystem).Domain }
      )
  Add-Member -InputObject $IPGlobalProperties -MemberType NoteProperty -Name 'WorkGroup'            -Value ($_ =
      (Get-Win32_ComputerSystem).Workgroup
      )
  Add-Member -InputObject $IPGlobalProperties -MemberType NoteProperty -Name 'NodeType'             -Value ($_ =
      $ipProperties.NodeType
      )
  Add-Member -InputObject $IPGlobalProperties -MemberType NoteProperty -Name 'DomainRole'           -Value ($_ =
      (Get-Win32_ComputerSystem).DomainRole
      )
  Add-Member -InputObject $IPGlobalProperties -MemberType NoteProperty -Name 'IsWinsProxy'          -Value ($_ =
      [Boolean]($ipProperties.IsWinsProxy)
      )
  Add-Member -InputObject $IPGlobalProperties -MemberType NoteProperty -Name 'DhcpScopeName'        -Value ($_ =
      $ipProperties.DhcpScopeName
      )
  Add-Member -InputObject $IPGlobalProperties -MemberType NoteProperty -Name 'IsNetworkAvailable'   -Value ($_ =
      [Boolean]([System.Net.NetworkInformation.NetworkInterface]::GetIsNetworkAvailable())
      )
  Add-Member -InputObject $IPGlobalProperties -MemberType NoteProperty -Name 'MacAddresses'         -Value ($_ =
      @( Gwmi -Class Win32_NetworkAdapterConfiguration | ?{ $_.MacAddress } | %{ $_.MacAddress } )
      )
  Add-Member -InputObject $IPGlobalProperties -MemberType NoteProperty -Name 'IPAddresses'          -Value ($_ =
      @( Gwmi -Class Win32_NetworkAdapterConfiguration | ?{ $_.IPAddress } | %{ $_.IPAddress } )
      )
  Add-Member -InputObject $IPGlobalProperties -MemberType NoteProperty -Name 'DefaultIPGateways'    -Value ($_ =
      @( Gwmi -Class Win32_NetworkAdapterConfiguration | ?{ $_.DefaultIPGateway } | %{ $_.DefaultIPGateway } )
      )
  Add-Member -InputObject $IPGlobalProperties -MemberType NoteProperty -Name 'DHCPServers'          -Value ($_ =
      @( Gwmi -Class Win32_NetworkAdapterConfiguration | ?{ $_.DHCPServer } | %{ $_.DHCPServer } )
      )
  Add-Member -InputObject $IPGlobalProperties -MemberType NoteProperty -Name 'DNSServers'           -Value ($_ =
      @( Gwmi -Class Win32_NetworkAdapterConfiguration | ?{ $_.DNSServerSearchOrder } | %{ $_.DNSServerSearchOrder } )
      )

  $IPGlobalProperties
}

function Get-Uptime {
  [CmdletBinding()] Param()

  $WinLogonKey = "Software\Microsoft\Windows NT\CurrentVersion\WinLogon"

  if ( $UserShell = Get-ItemProperty -Path "HKCU:$WinLogonKey" | Select-Object -ExpandProperty Shell -ea 0 ) {
    ;
  } else {
    $UserShell = Get-ItemProperty -Path "HKLM:$WinLogonKey" | Select-Object -ExpandProperty Shell -ea 0
  }
  Write-Verbose "Shell is $UserShell"

  [DateTime]$InstallDate            = Get-Date $((Get-Win32_OperatingSystem).ConvertToDateTime((Get-Win32_OperatingSystem).InstallDate))
  [DateTime]$LastBootUpTime         = Get-Date $((Get-Win32_OperatingSystem).ConvertToDateTime((Get-Win32_OperatingSystem).LastBootUpTime))
  [DateTime]$LastServerReset        = Get-Date $((net statistics server       | ?{ $_ -imatch "since" }) -replace ".*since ")
  [DateTime]$LastWorkStationReset   = Get-Date $((net statistics workstation  | ?{ $_ -imatch "since" }) -replace ".*since ")
  [DateTime]$UserLastLogonTime      = Get-Date $((net user $Env:UserName      | ?{ $_ -imatch "^Last logon" }) -replace ".*\ \ ")
  [DateTime]$now                    = Get-Date
  [DateTime]$ProcessStartTime       = (Get-Process -ID $PID | Select-Object -ExpandProperty StartTime).DateTime
  [DateTime]$ShellStartTime         = Gwmi Win32_process | ?{ $_.Name -ieq $UserShell } |
                                       Select Name,ProcessID,@{n='Owner';e={$_.GetOwner().User}} |
                                       ?{ ($_.Owner -eq $Env:UserName) } |
                                       %{ [DateTime](Get-Process -ID $_.ProcessID | Select-Object -ExpandProperty StartTime).DateTime }
  [TimeSpan]$InstallUptime  = $now - $InstallDate
  [TimeSpan]$Uptime         = $now - $LastBootupTime
  [TimeSpan]$ServerUptime   = $now - $LastServerReset
  [TimeSpan]$WorkStationUptime  = $now - $LastWorkStationReset
  [TimeSpan]$UserUptime     = $now - $UserLastLogonTime
  [TimeSpan]$ShellUptime    = $now - $ShellStartTime
  [TimeSpan]$ProcessUptime  = $now - $ProcessStartTime

  $OutputObject = New-Object PSObject

  $OutputObject | Add-Member NoteProperty 'CurrentTime'           $now                  -PassThru |
                  Add-Member NoteProperty 'BootTime'              $LastBootUpTime       -PassThru |
                  Add-Member NoteProperty 'UpTime'                $Uptime               -PassThru |
                  Add-Member NoteProperty 'InstallTime'           $InstallDate          -PassThru |
                  Add-Member NoteProperty 'InstallUptime'         $InstallUptime        -PassThru |
                  Add-Member NoteProperty 'ServerStartTime'       $LastServerReset      -PassThru |
                  Add-Member NoteProperty 'ServerUptime'          $ServerUptime         -PassThru |
                  Add-Member NoteProperty 'WorkStationStartTime'  $LastWorkStationReset -PassThru |
                  Add-Member NoteProperty 'WorkStationUptime'     $WorkStationUptime    -PassThru |
                  Add-Member NoteProperty 'UserLastLogonTime'     $UserLastLogonTime    -PassThru |
                  Add-Member NoteProperty 'UserUptime'            $UserUptime           -PassThru |
                  Add-Member NoteProperty 'ShellStarttime'        $ShellStartTime       -PassThru |
                  Add-Member NoteProperty 'ShellUptime'           $ShellUptime          -PassThru |
                  Add-Member NoteProperty 'ProcessStartTime'      $ProcessStartTime     -PassThru |
                  Add-Member NoteProperty 'ProcessUptime'         $ProcessUptime        -PassThru

}

function Get-MacAddress {
  [CmdletBinding()] Param()


  $GetMac = & getmac.exe /fo csv | ConvertFrom-CSV

  $Keys = $GetMac | gm -MemberType NoteProperty | Select -Expand Name

  $GetMac | %{
    $This = $_
    $Result = New-Object PSObject
    $Keys | %{
      $Key = $_       -replace '\s+',''
      $Val = $This.$_ -replace '\s+',''
      $Result | Add-Member NoteProperty ($Key) ($Val)
      if ( $Key -imatch 'PhysicalAddress' ) {
        $Result | Add-Member NoteProperty MACAddress  ($Val -replace '-',':')
        $Result | Add-Member NoteProperty NetFormat ((($Val -replace "-") -split '(....)' | ?{$_}) -join '.')
        $Result | Add-Member NoteProperty OUI ($Result.MacAddress.SubString(0,8))
        $Result | Add-Member NoteProperty NIC ($Result.MacAddress.SubString(9))
      }
    }
    Write-Output $Result
  }
}

function Get-Nic {
  netsh.exe interface show interface | ?{ $_ -inotmatch '^$|^Admin State|^----' } | %{
    ($AdminState, $State, $Type, $InterfaceName) = ($_ -split '\s\s+')
    $Int = New-Object PSObject
    $Int | Add-Member NoteProperty AdminState $AdminState -PassThru |
           Add-Member NoteProperty State      $State      -PassThru |
           Add-Member NoteProperty Type       $Type       -PassThru |
           Add-Member NoteProperty InterfaceName $InterfaceName
    Write-Output $Int
  }
}

# # TODO : This needs attentions - broken
# function Get-Nic {
#   [CmdletBinding()] Param(
#   )
#
#   $CurrentAdapter = $LastKey = $Begin = $Null
#   $ipconfig = ipconfig.exe /all
#
#   $This = New-Object PSObject
#
#   foreach ($Line in $Ipconfig) {
#
#     if ( $Line -imatch '^\S+\s+adapter' ) {
#       Write-Host -Fore Magenta "AD, $Line"
#       ($Type, $Name) = ([Regex]::Match( $Line, '^(\S+)\s+adapter\s+(\S.*):\s*$' )).Groups[1,2]
#       $This | Add-Member NoteProperty Type $Type
#       $This | Add-Member NoteProperty Name $Name
#       $Begin = $True
#     }
#     elseif ( $Begin ) {
#       if ( ($K, $V) = ([Regex]::Match( $Line, '^\s*(\S.*?)\s*:\s*(\S.*)\s*$' )).Groups[1,2] ) {
#         $K = $K -replace '(?:\ ?\.?)+\s*$',''
#
#         if ( $K ) {
#           Write-Host -Fore Magenta "KV, $Line"
#           $LastKey = $K
#           $This | Add-Member NoteProperty $K $V
#         }
#         else {
#           Write-Host -Fore Magenta " V, $Line"
#           $V = $Line -replace '^\s+|\s+$',''
#           $E = $This.$LastKey
#           $This | Add-Member NoteProperty $LastKey @($E,$V) -Force
#         }
#       }
#     }
#     elseif ( $Begin -and ($Line -match '^\s*$') ) {
#       Write-Host -Fore Magenta "BL, [$This]"
#       if ( $This | gm -MemberType NoteProperty ) { # Object is defined.
#         Write-Output $This
#         $This = New-Object PSObject
#         $Begin = $False
#       } else {
#         $Begin = $True
#       }
#     }
#
#   }
#
# }

function Get-RegKey {
  [CmdletBinding()] Param(
    [String] $Key
  )
  $Raw  = Get-ItemProperty $Key
  $Raw | gm -MemberType NoteProperty | ?{ $_.Name -notlike 'PS*' -and $_.Name -like 'AA*' } | %{ $_.Name } | %{
    $Record = New-Object PSObject
    $Record | Add-Member NoteProperty 'Property'  $_
    $Record | Add-Member NoteProperty 'Value'     $Raw.($_)
    $Record | Add-Member NoteProperty 'Type'      $Raw.($_).GetType()
    $RegType = Switch -Regex ( $Raw.($_).GetType().Name ) {
      "^Byte\[\]$"    { 'REG_BINARY'  ; break; }
      "^Int64$"       { 'REG_QWORD'   ; break; }
      "^Int32$"       { 'REG_DWORD'   ; break; }
      "^String$"      { 'REG_SZ'      ; break; }
      "^String\[\]$"  { 'REG_MULTI_SZ'; break; }
      default      { 'UNKNOWN'   ; break; }
    }
    $Record | Add-Member NoteProperty 'RegType' $RegType
    $Record | Add-Member NoteProperty 'Key'     $Key
    $Record | Add-Member NoteProperty 'RegKey'  (Convert-Path $Key)
    Write-Output $Record
  }
}

function Get-OSVersion {
  [CmdletBinding()] Param()

  $This = gp 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' | Select -Exclude PS* *

  $Caption = ((Get-Win32_OperatingSystem).Caption) -replace '[^\w\s\.]|^\s+|\s+$',''

  ([String]$Vendor, [String]$Product, [String]$CaptionShort, [String]$ProductEdition) =
    ([Regex]::Match( $Caption, "^(Microsoft)\s*(Windows)\s*(.*?)\s+(\S+)\s*$" )).Groups[1,2,3,4]

  $This =
  $This | Add-Member -Force -PassThru NoteProperty Version        ([Version](Get-Win32_OperatingSystem).Version) |
          Add-Member -Force -PassThru NoteProperty Caption        $Caption      |
          Add-Member -Force -PassThru NoteProperty CaptionAlt `
            (("{0} {1}" -f $This.ProductName, $This.InstallationType) -replace '(Microsoft|Windows|Server) *','') |
          Add-Member -Force -PassThru NoteProperty ServicePackVersion `
            ([Version]("{0}.{1}" -f (Get-Win32_OperatingSystem).ServicePackMajorVersion, (Get-Win32_OperatingSystem).ServicePackMinorVersion)) |
          Add-Member -Force -PassThru NoteProperty OSArchitecture (Get-Win32_OperatingSystem).OSArchitecture |
          Add-Member -Force -PassThru NoteProperty ProcessorAddressWidth  (Get-Win32_Processor)[0].AddressWidth      |
          Add-Member -Force -PassThru NoteProperty OSType         ($Type = if ($Caption -imatch 'Server') { 'Server' } else { 'Workstation' })

  [Environment]::OSVersion | gm -MemberType Property | %{
    $This | Add-Member -Force NoteProperty $_.Name ([Environment]::OSVersion).($_.Name)
  }

  $This
}

function Get-ImageID {
  [CmdletBinding()] Param(
    [String] $Template = '%p_%t_%v_SP%s_%a_%l_%y%m%4G'
  )

  $String = $Template -split '(%[^%]+)' | ?{$_} | %{
    Write-Verbose "Field : $_"
    Switch -Case -Regex ($_) {
      '%P.*'    { $_ -replace '%P', (Get-OSVersion).ProductName -replace '[^A-Z0-9\.]','_' }
      '%p.*'    { $_ -replace '%p', (Get-OSVersion).CaptionAlt -replace '[^A-Z0-9\.]','_' }
      '%v.*'    { $_ -replace '%v', (Get-Win32_OperatingSystem).Version }
      '%V.*'    { $_ -replace '%V', ([System.Version][Environment]::OSVersion.Version)  }
      '%[Ss].*' { $_ -replace '%s', (Get-OSVersion).ServicePackVersion  }
      '%[Aa].*' { $_ -replAce '%A', (Get-CPU -Architecture)  }
      '%[Tt].*' { $_ -replAce '%T', (Get-OSVersion).InstallationType  }
      '%[Ll].*' { $_ -replAce '%L', $Host.CurrentCulture  }
      '%Y.*'    { $_ -replAce '%y', (Get-Date -UFormat '%Y')  }
      '%y.*'    { $_ -replAce '%y', (Get-Date -UFormat '%y')  }
      '%m.*'    { $_ -replAce '%m', (Get-Date -UFormat '%m')  }
      '%\d*[Gg].*' {
        [Int32]  $Rep = [String]([Regex]::Match($_, '%(\d*)[Gg]')).Groups[1]
        [String] $MachineGuid = (Get-MachineId).MachineGuid
        $_ -replace '%\d*[Gg]', ( $MachineGuid.SubString($MachineGuid.Length-$Rep) )
      }
      '%\d*[Rr].*' {
        [Int32]$Rep = [String]([Regex]::Match($_, '%(\d*)[Rr]')).Groups[1]
        $_ -replace '%\d*[Rr]', (Get-RandomString -Length $Rep -WhiteList '[A-Fa-f0-9]' -Verbose:$False)
      }
    }
  }
  $String -join ""

<#
.SYNOPSIS
Generate an identifier for the installed operating system.

.NOTES
  # A, a    - Arcitecture/Bitness e.g.
  # L, l    - UI Culture/Locale e.g. en-GB, en-US
  # p       - Product Abbreviation 4Letter e.g. Win7
  # P       - Product e.g. Windows7
  # R, r    - Random Char
  # S, s    - Service Pack Number e.g. 1, 2
  # T, t    - Product Type e.g. Standard, Enterprise
  # V, v    - Version Number e.g. 6.1.7601.65535
  # Y       - Year, y4 - e.g. 2014
  # y       - Year, y2 - e.g. 14
#>
}

function Get-ImageState {
  Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Setup\State' | Select-Object -ExpandProperty ImageState
}

function Set-WindowsErrorReporting {
  [CmdletBinding()] Param(
    [Switch]$Enabled
  )
  & reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v DontShowUI /t REG_DWORD (([Boolean]$Enabled) -bxor $True)
  & reg.exe add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled   /t REG_DWORD (([Boolean]$Enabled) -bxor $True)
}

function Enable-WindowsErrorReporting {
  [CmdletBinding()] Param() Set-WindowsErrorReporting -Enabled
}

function Disable-WindowsErrorReporting {
  [CmdletBinding()] Param()
  Set-WindowsErrorReporting -Enabled:$False
}

function Set-HostName {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$False)] [String] $ComputerName,
    [Alias('Hostname')]
      [Parameter(Mandatory=$True)][String] $NewName,
    [Parameter(Mandatory=$False)] [String] $Username,
    [Parameter(Mandatory=$False)] [String] $Password,
    [Parameter(Mandatory=$False)] [Switch] $Restart
  )
  try {
    $Win32_ComputerSystem = Get-Win32_ComputerSystem
    if ( $Username ) {
      $Win32_ComputerSystem.Rename($HostName, $Password, $Username)
    }
    else {
      $Win32_ComputerSystem.Rename($HostName)
    }
    if ( $Restart ) { Restart-Computer }
  } catch {
    Throw "Error renaming host to '$Hostname' ($Env:COMPUTERNAME) : $_"
  }
}
if ( -not(gcm Rename-Computer -ea 0) ) {
  sal Rename-Computer Set-Hostname
}

function Set-WSHScriptHost {
  [CmdletBinding()] Param(
    $scripthost = "cscript" )
  $scripthost = $scripthost -replace "\.exe$"
  Write-Verbose "Setting WSH Script Host to '$scripthost'."
  & cscript.exe //H:$scripthost
}

function Invoke-Sysprep {
  [CmdletBinding()] Param(
    [Alias('Unattend', 'Unattended')]
      [String]$AnswerFile,
    [Switch] $Generalize,
    [Switch] $Oobe,
    [Switch] $Quit,
    [Switch] $Shutdown,
    [Switch] $Reboot,
    [Switch] $Quiet,
    [Switch] $Audit,
    [String] $Mode
  )
  # TODO - Look at reusing the unattend.xml files
  # Support modes

  if (Test-Path($sysprep = ls (Join-Path $Env:SystemRoot "System32\Sysprep\sysprep.exe") | %{$_.FullName})) {
    if ( [Double](Get-OSVersion).CurrentVersion -lt 6 ) { # xp
    # $args = ('-reseal', '-activated', '-mini',  '-noreboot')
      $args = ('-audit',  '-quiet')
    }
    else {
      if ( $Quiet      )  { $args+=( '-quiet'                ) }
      if ( $Generalize )  { $args+=( '-generalize'           ) }
      if ( $Audit      )  { $args+=( '-audit'                ) }
      if ( $Oobe       )  { $args+=( '-oobe'                 ) }
      if ( $Shutdown   )  { $args+=( '-shutdown'             ) }
      if ( $Reboot     )  { $args+=( '-Reboot'               ) }
      if ( $Quit       )  { $args+=( '-quit'                 ) }
      if ( $AnswerFile )  { $args+=( "-unattend:$AnswerFile" ) }
      if ( $Mode       )  { $args+=( "-mode:$Mode"           ) }

      if ( -not( $args.count ) ) {
        $args = ('-oobe', '-generalize', '-quit')
      }
    }

    Write-Verbose "  Invoking $sysprep $args"
    if ( $process = Start-Process -FilePath $sysprep -ArgumentList $args -PassThru ) {
      $process | Wait-Process
      return $process.ExitCode
    } else {
      Throw "Sysprep did not complete successfully."
    }
  }
  else {
    Throw "Unable to find sysprep on this installation."
  }
}

function Set-ShutdownTrackerPreference {
  [CmdletBinding()]Param(
    [Boolean]$Enabled
  )
  Write-Verbose "Setting shutdown tracker to enabled : '$Enabled'"
  & reg.exe add "HKLM\Software\Microsoft\Windows\CurrentVersion\Reliability" /f /v "ShutdownReasonUI" /t REG_DWORD /d ([Int]$Enabled) | Write-Verbose
}

function Enable-ShutdownTracker {
  [CmdletBinding()] Param()
  Write-Verbose "Enabling shutdown tracker"
  Set-ShutdownTrackerPreference -Enabled $True
}

function Disable-ShutdownTracker {
  [CmdletBinding()]Param()
  Write-Verbose "Disabling shutdown tracker"
  Set-ShutdownTrackerPreference -Enabled $False
}

# ---- Network Location Prompt --

function Set-NetworkLocation {
  [CmdletBinding()] Param(
      [String] $NetworkName = 'Unknown',
      [String][ValidateSet('Public','Private')] $Category = 'Private',
      [String][ValidateSet('House','Office','Bench')] $IconPath = 'Office'
    )

  [Int]$NetworkCategory = ($_ = if ($Category -imatch 'Private') { 1 } else { 0 })

  reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\FirstNetwork' /f /v NetworkName /t REG_SZ /d $NetworkName | Write-Verbose
  reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\FirstNetwork' /f /v Category    /t REG_DWORD /d $NetworkCategory | Write-Verbose
  reg.exe add 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\FirstNetwork' /f /v IconPath    /t REG_SZ /d ("%WINDIR%\system32\NetworkList\Icons\StockIcons\{0}" -f $IconPath) | Write-Verbose
}

function Disable-NetworkLocationPrompt {
  [CmdletBinding()] Param(
  )

  try {
    reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Network'                  /f | Write-Verbose
    reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList'              /f | Write-Verbose
    reg.exe add 'HKLM\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff'          /f | Write-Verbose
    reg.exe add 'HLKM\SYSTEM\CurrentControlSet\Control\Network\NetworkLocationWizard'        /f | Write-Verbose
    reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\NewNetworks'  /f /v NetworkList /t REG_MULTI_SZ /d 00000000   | Write-Verbose
    reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Network\NwCategoryWizard' /f /v Show        /t REG_DWORD    /d 0x00000000 | Write-Verbose
    reg.exe add 'HLKM\SYSTEM\CurrentControlSet\Control\Network\NetworkLocationWizard'        /f /v HideWizard  /t REG_DWORD    /d 0x00000001 | Write-Verbose
  } catch {
    Write-Warning "One of more attempts to configure the network location wizard failed."
  }
}

# ---- Crash Control ----

function Get-CrashControlParameter {
  [CmdletBinding()] Param(
    [String]$Name
  )
  Get-ItemProperty -Path $CrashControlRegKeyP -Name $Name | Select-Object -ExpandProperty $Name -ea 0
}

function Set-CrashControlCrashDumpType {
  [CmdletBinding()] Param(
    [Int]$Value
  )
  # Values as per
  # http://technet.microsoft.com/en-us/library/cc976050.aspx
  & reg.exe add "$CrashControlRegKey" /f /v  "CrashDumpEnabled" /t REG_DWORD /d $Value | Write-Verbose
}

function Get-CrashControlCrashDumpType {
  [CmdletBinding()] Param()
  Get-CrashControlParameter -Name 'CrashDumpEnabled'
}

function Disable-CrashControlCrashDump {
  [CmdletBinding()] Param()
  Set-CrashControlCrashDumpType -Value 0
}

function Enable-CrashControlCrashDump {
  [CmdletBinding()] Param(
    [Int]$Value = 1 # 0|1|2|3
  )
  Set-CrashControlCrashDumpType -Value $Value
}

function Set-NMICrashDump {
  [CmdletBinding()] Param(
    [Int]$Value
  )
  # http://support.microsoft.com/kb/927069
  & reg.exe add "$CrashControlRegKey" /f /v  "NMICrashDump" /t REG_DWORD /d $Value | Write-Verbose
}

function Get-CrashControlNMICrashDump {
  [CmdletBinding()] Param()
  Get-CrashControlParameter -Name 'NMICrashDump'
}

function Disable-NMICrashDump {
  [CmdletBinding()] Param()
  Set-NMICrashDump -Value 0
}

function Enable-NMICrashDump {
  [CmdletBinding()] Param(
    [Int]$Value = 1 )
  Set-NMICrashDump -Value $Value
}

function Set-CrashControlAutoReboot {
  [CmdletBinding()] Param(
    [Int]$Value = 1
  )
  & reg.exe add "$CrashControlRegKey" /f /v  "AutoReboot" /t REG_DWORD /d $Value | Write-Verbose
}

function Get-CrashControlAutoReboot {
  [CmdletBinding()] Param()
  Get-CrashControlParameter -Name 'AutoReboot'
}

function Disable-CrashControlAutoReboot {
  [CmdletBinding()] Param()
  Set-CrashControlAutoReboot -Value $False
}

function Enable-CrashControlAutoReboot {
  [CmdletBinding()] Param()
  Set-CrashControlAutoReboot -Value $True
}

function Disable-AutoRebootOnSystemFailure {
  [CmdletBinding()] Param() Write-Verbose "Disabling AutoRebootOnSystemFailure"
  $Status = & wmic recoveros set AutoReboot = False
  Write-Verbose "  Status: $Status"
}

function Set-CrashControlLogEvent {
  [CmdletBinding()] Param(
    [Int]$Value = 0 # Default; Don't log
  )
  & reg.exe add "$CrashControlRegKey" /f /v "LogEvent" /t REG_DWORD /d $Value | Write-Verbose
}

function Get-CrashControlLogEvent {
  [CmdletBinding()] Param()
  Get-CrashControlParameter -Name 'LogEvent'
}

function Disable-CrashControlLogEvent {
  [CmdletBinding()] Param()
  Set-CrashControlLogEvent -Value $False
}

function Enable-CrashControlLogEvent {
  [CmdletBinding()] Param()
  Set-CrashControlLogEvent -Value $True
}

function Set-CrashControlDumpFileLocation {
  [CmdletBinding()] Param(
    [String]$DumpFileLocation = (Join-Path $Env:SYSTEMROOT "Memory.dmp")
  )
  & reg.exe add "$CrashControlRegKey" /f /v "DumpFile" /t REG_EXPAND_SZ /d $DumpFileLocation | Write-Verbose
}

function Get-CrashControlDumpFileLocation {
  [CmdletBinding()] Param()
  Get-CrashControlParameter -Name 'DumpFile'
}

function Set-CrashControlDumpFileSize {
  [CmdletBinding()] Param(
    [Int32]$DumpFileSize = 0 # Default; Allow system to determine size
  )

  & reg.exe add "$CrashControlRegKey" /f /v "DumpFileSize" /t REG_DWORD /d $DumpFileSize | Write-Verbose
}

function Get-CrashControlDumpFileSize {
  [CmdletBinding()] Param()
  Get-CrashControlParameter -Name 'DumpFileSize'
}

function Set-CrashControlDedicatedDumpFileLocation {
  [CmdletBinding()] Param(
    [String]$DumpFileLocation = (Join-Path $Env:SYSTEMROOT "DedicatedDump.sys")
  )
  & reg.exe add "$CrashControlRegKey" /f /v "DedicatedDumpFile" /t REG_EXPAND_SZ /d $DumpFileLocation | Write-Verbose
}

function Get-CrashControlDedicatedDumpFileLocation {
  [CmdletBinding()] Param()
  Get-CrashControlParameter -Name 'DedicatedDumpFile'
}

function Set-CrashControlMiniDumpDirectory {
  [CmdletBinding()] Param(
    [String]$MiniDumpDirectory = (Join-Path $Env:SYSTEMROOT "Minidump")
  )
  & reg.exe add "$CrashControlRegKey" /f /v "MinidumpDir" /t REG_EXPAND_SZ /d $MiniDumpDirectory | Write-Verbose
}

function Get-CrashControlMiniDumpDirectory {
  [CmdletBinding()] Param()
  Get-CrashControlParameter -Name 'MinidumpDir'
}

function Set-CrashControlMiniDumpCount {
  [CmdletBinding()] Param(
    [Int32]$MiniDumpCount = 0x32  # Default; 50
  )
  & reg.exe add "$CrashControlRegKey" /f /v "MinidumpsCount" /t REG_DWORD /d $MiniDumpCount | Write-Verbose
}

function Get-CrashControlMiniDumpCount {
  [CmdletBinding()] Param()
  Get-CrashControlParameter -Name 'MinidumpsCount'
}

function Set-CrashControlDumpFileOverWrite {
  [CmdletBinding()] Param(
    [Int]$Value = 1 # Default; OverWrite
  )
  & reg.exe add "$CrashControlRegKey" /f /v "OverWrite" /t REG_DWORD /d $Value | Write-Verbose
}

function Get-CrashControlDumpFileOverWrite {
  [CmdletBinding()] Param()
  Get-CrashControlParameter -Name 'OverWrite'
}

function Disable-CrashControlDumpFileOverWrite {
  [CmdletBinding()] Param()
  Set-CrashControlDumpFileOverWrite -Value $False
}

function Enable-CrashControlDumpFileOverWrite {
  [CmdletBinding()] Param()
  Set-CrashControlDumpFileOverWrite -Value $True
}

function Set-CrashControlSendAlert {
  [CmdletBinding()] Param(
    [Int]$Value = 1
  )
  & reg.exe add "$CrashControlRegKey" /f /v "SendAlert" /t REG_DWORD /d $Value | Write-Verbose
}

function Get-CrashControlSendAlert {
  [CmdletBinding()] Param()
  Get-CrashControlParameter -Name 'SendAlert'
}

function Disable-CrashControlSendAlert {
  [CmdletBinding()] Param()
  Set-CrashControlSendAlert -Value $False
}

function Enable-CrashControlSendAlert {
  [CmdletBinding()] Param()
  Set-CrashControlSendAlert -Value $True
}

function Set-CrashControlAlwaysKeepMemoryDump {
  [CmdletBinding()] Param(
    [Int]$Value = 1
  )
  & reg.exe add "$CrashControlRegKey" /f /v "AlwaysKeepMemoryDump" /t REG_DWORD /d $Value | Write-Verbose
}

function Get-CrashControlAlwaysKeepMemoryDump {
  [CmdletBinding()] Param()
  Get-CrashControlParameter -Name 'AlwaysKeepMemoryDump'
}

function Disable-CrashControlAlwaysKeepMemoryDump {
  [CmdletBinding()] Param()
  Set-CrashControlAlwaysKeepMemoryDump -Value $False
}

function Enable-CrashControlAlwaysKeepMemoryDump {
  [CmdletBinding()] Param()
  Set-CrashControlAlwaysKeepMemoryDump -Value $True
}

function Get-CrashControlSettings {
  [CmdletBinding()] Param()
  Gwmi -Class Win32_OSRecoveryConfiguration |  Select -ExcludeProperty ClassPath,Path,*Options,*Properties,*Scope -Property '[A-Z]*'
}

# ---- UserLogon ----

function Get-AutoAdminLogon {                   #M:UserLogon
  [CmdletBinding()] Param(
  )
  Get-ItemProperty 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\WinLogon' | Select AutoAdmin*
}

function Set-AutoAdminLogon {                   #M:UserLogon
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$False)] [String]  $DefaultUserName     = $Env:USERNAME,
    [Parameter(Mandatory=$False)] [String]  $DefaultPassword     = '-',
    [Parameter(Mandatory=$False)] [String]  $DefaultDomainName,
    [Parameter(Mandatory=$False)] [Switch]  $AutoAdminLogon      = $True
  )

  $DefaultDomainName = if ( ($local:gwmi = (Get-Win32_ComputerSystem)).PartOfDomain ) {
    $gwmi.Domain
  }
  else {
    ([System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()).HostName
    # $gwmi.DNSHostName # This fails on XP ??
  }

  & reg.exe add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /f   /v AutoAdminLogon      /t REG_SZ     /d ([Int][Boolean]$AutoAdminLogon) | Write-Verbose
  & reg.exe add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /f   /v DefaultDomainName   /t REG_SZ     /d $DefaultDomainName | Write-Verbose
  & reg.exe add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /f   /v DefaultUserName     /t REG_SZ     /d $DefaultUserName | Write-Verbose
  & reg.exe add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /f   /v DefaultPassword     /t REG_SZ     /d $DefaultPassword | Write-Verbose
}

function Enable-AutoAdminLogon {                #M:UserLogon
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$False)] [System.Boolean] $AutoAdminLogon     = $True
  )
  # Show-Invocation
  Write-Verbose  "Enabling Administrative AutoLogon"
  Set-AutoAdminLogon -AutoAdminLogon ([Int]$False)
}

function Disable-AutoAdminLogon {               #M:UserLogon
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$False)] [System.Boolean] $AutoAdminLogon     = $True
  )
  Write-Verbose  "Disabling Administrative AutoLogon"
  Set-AutoAdminLogon -AutoAdminLogon ([Int]$True)
}

function Uninstall-UserLogonScript {            #M:UserLogon
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$False)] 
    [Alias('Description','ValueName')]
      [String]$Name
  )
  Write-Verbose "Removing $Name from user logon start."

  & reg.exe delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v $Name /f | Write-Verbose
}

function Install-LogonScript {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)]
    [Alias('ScriptPath')]
      [String]$Script,
    [Alias('Description','ValueName')]
      [String]$Name = $Script,
    [Switch]$Global = $True,
    [Switch]$User,
    [Switch]$RunOnce,
    [Switch]$Hidden
  )

  if ( -not (Test-Path $Script -ea 0) ) {
    Write-Warning "Script $Script does not exist and so may not be invoked on logon. Proceeding anyway .."
  }

  $RegistryScope  = if ( $Global )  { "HKLM"    } elseif ( $User ) { "HKCU" }
  $RunKey         = if ( $RunOnce ) { "RunOnce" } else  { "Run" }
  $TargetKey      = "{0}\SOFTWARE\Microsoft\Windows\CurrentVersion\{1}" -f $RegistryScope,$RunKey

  $StartupCommand = if ($Hidden) {
    $ScriptContents = @"
If WScript.Arguments.Count = 1 Then
  CreateObject("Wscript.Shell").Run WScript.Arguments.Item(0), 0, True
End If
"@
    $WrapperScript = '{0}.vbs' -f $Script
    $ScriptContents | Out-File -Encoding ASCII -FilePath $WrapperScript -Force
    "{0} {1}" -f (Resolve-Path $WrapperScript).ProviderPath, $Script
  }
  else {
    $Script
  }

  Set-ItemProperty -Path "Registry::$TargetKey" -Name $Name -Value $StartupCommand `
                   -Type String -Verbose:$VerbosePreference -ea 1
  # Write-Verbose "  reg.exe add '$TargetKey' /f /v $Name /t REG_SZ /d $StartupCommand"
  # & reg.exe add $TargetKey /v $Name /t REG_SZ /d $StartupCommand /f | Write-Verbose
}

function Install-GlobalLogonScript {            #M:UserLogon
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)]
    [Alias("ScriptPath")]
      [String]$Script,
    [Parameter(Mandatory=$False)]
    [Alias("Description",'ValueName')]
      [String]$Name = $Script,
    [Switch]$Hidden
  )
  if (-not $Name) { $Name = $Script }
  Install-LogonScript -Script $Script -Description $Name -Global -Hidden:$Hidden
}

function Install-RebootTest { # TODO: Remove - this is a test case
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)]
      [String]$ScriptPath,
    [Parameter(Mandatory=$False)]
      [String]$LogFile = (New-TempFile -Template "$($ScriptPath -replace '.*\\','')-XXXXXX.log" -AsString)
  )

    Write-Verbose "Writing test batch file"
    $ScriptContents = @"
  @echo off
  echo SCRIPT       : %0                 > $LogFile
  echo DIR          : %~dp0             >> $LogFile
  echo TIME         : %DATE%%TIME%      >> $LogFile
  echo ARGS         : %*                >> $LogFile
  echo USERNAME     : %USERNAME%        >> $LogFile
  echo COMPUTERNAME : %COMPUTERNAME%    >> $LogFile
  shutdown.exe -r -t 60 -c "The VM Guest Tools installer completed successfully. A reboot is now required. Please Stand by!"
"@
    $ScriptContents | Out-File -Encoding ASCII -FilePath $ScriptPath -Force
}

function Install-MachineStartupScript {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)]
      [String]$ScriptPath,
    [Parameter(Mandatory=$False)]
      [String[]]$ScriptParameters,
    [Parameter(Mandatory=$False)]
      [String]$LogFile = (New-TempFile -Template "$($ScriptPath -replace '.*\\','')-XXXXXX.log" -AsString),
    [Switch] $Force
  )

  $ScriptPath               = Resolve-Path $ScriptPath
  $ScriptPathEscaped        = $ScriptPath -replace '\\', '\\'
  $ScriptParametersEscaped  = $ScriptParameters -join ' '
  $ScriptsIniPath           = "$Env:Windir\System32\GroupPolicy\Machine\Scripts\scripts.ini"
  $GptIniPath               = "$Env:Windir\System32\GroupPolicy\gpt.ini"
  $RegFile                  = New-TempFile -Template 'MachineStart-XXXXXX.reg'

  Write-Verbose "Creating GroupPolicy script directories"
  $ScriptDirs = "$Env:WINDIR\System32\GroupPolicy\Machine\Scripts" | %{ ("$_\Startup", "$_\ShutDown") }
  $ScriptDirs, $ScriptPath, $ScriptsIniPath, $GptIniPath, $RegFile | %{$_} | %{
    if ( -not(Test-Path($Parent = Split-Path $_ -Parent)) ) {
      Write-Verbose "  mkdir $_"
      mkdir -Force $Parent | Out-Null
    }
  }

  if ( (Test-Path $ScriptPath) -and -not(Test-Path $ScriptPath -PathType Leaf) ) {
    Throw "$($MyInvocation.MyCommand.Name): ScriptPath '$ScriptPath' is not a file, cannot proceed."
  }

  Write-Verbose ""
  Write-Verbose "Determining next major task number"
  $MajorKeys      = @( Get-Item 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\*' -ea 0)

  # Do a first pass scan over the key to see if this script was previously registered
  $TargetKey = foreach ( $i in @(0 .. $MajorKeys.Count) ) {
    Write-Verbose ""
    $MinorKeys  = @( Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\$i\*" -ea 0)
    $TargetKey  = $MinorKeys | %{
      $Script = $_.GetValue('Script')
      $Args   = $_.GetValue('Parameters')
      if ( ($Script -ieq $ScriptPath) -and ($Args -ceq $ScriptParametersEscaped) ) {
        # Match only if script and args match (Args must match _precisely_)
        Write-Verbose "    Match found. ('$Script' $Args)"
        Write-Verbose "             ==  ('$ScriptPath' $ScriptParametersEscaped)"
        return $_
      }
    }

    if ($TargetKey) {
      $Return = New-Object PSObject
      $SubKeyIndex    = (Split-Path $TargetKey.Name -Leaf)                    # e.g. 1/0 => 0
      $ParentKeyIndex = Split-Path (Split-Path $TargetKey.Name -Parent) -Leaf # e.g. 1/0 => 1
      Write-Verbose "  Task number : $ParentKeyIndex/$SubKeyIndex"
      $Return | Add-Member NoteProperty MajorKey $ParentKeyIndex -PassThru |
                Add-Member NoteProperty MinorKey $SubKeyIndex
      return $Return
    }
  }

  if ( -not($TargetKey) ) {
    $TargetKey = New-Object PSObject
    $TargetKey  | Add-Member NoteProperty MajorKey 0 -PassThru |
                  Add-Member NoteProperty MinorKey 0
  }

  # ---- scripts.ini ----

  # The scripts.ini is of the format
  #
  #   0CmdLine=C:\path\to\foo.exe
  #   0Parameter=arg1 arg2
  #   1CmdLine=C:\path\to\bar.exe
  #   1Parameter=arg1 arg2
  #
  # This non-hierarchical nature of the keys is in contradiction with the
  # hierarchical nature of the registry entries which have a major and minor keys.
  #
  # We don't assume to reflect the registry hierarchy but simply to add
  # our command line at a target index in the scripts.ini file

  $NewScriptsIniHash = if ( Test-Path $ScriptsIniPath ) {
    cat $ScriptsIniPath | % -begin {
      $ScriptsIniHash = @{}
    } -process {
      Write-Verbose "Examining : $_"
      if ( $Match = [Regex]::Match($_, '^\s*(\d+)(\S+)\s*=\s*(.*)\s*$') ) {
        if ( $Match.Success ) {
          $TargetIndex = $Match.Groups[1].Value # Number
          $TargetKey   = $Match.Groups[2].Value # 'CmdLine' or 'Parameters'
          $TargetValue = $Match.Groups[3].Value # User Values
          Write-Verbose "    $TargetIndex $TargetKey $TargetValue"
          if ( -not($ScriptsIniHash[$TargetIndex]) ) {
            $ScriptsIniHash[$TargetIndex] = @{}
          }
          $ScriptsIniHash[$TargetIndex].Add( $TargetKey, $TargetValue )
        }
      }
    }

    Write-Verbose "    TargetIndex ?? "
    $TargetIndex = if ( $TargetKey ) { $TargetKey.MajorKey } else { $ScriptsIniHash.Keys.Count }
    Write-Verbose "    TargetIndex : $TargetIndex"

    if ( $ScriptsIniHash.Contains($TargetIndex) ){
      $ScriptsIniHash.Remove($TargetIndex)
    }
    # Inject the new cmdline here
    $ScriptsIniHash.Add($TargetIndex, @{'CmdLine'=$ScriptPath; 'Parameters'=$ScriptParametersEscaped;})

    foreach ( $key in @($ScriptsIniHash.Keys | sort) ) {
      Write-Output ( "{0}{1}={2}" -f $key, 'CmdLine',     ($ScriptsIniHash[$key]).CmdLine    )
      Write-Output ( "{0}{1}={2}" -f $key, 'Parameters',  ($ScriptsIniHash[$key]).Parameters )
    }
  }
  else {
    Write-Output @("0CmdLine=$ScriptPath", "0Parameters=$ScriptParametersEscaped")
  }

  Write-Verbose "Writing out scripts.ini file ($ScriptsIniPath)."
  (@( '', '[Startup]', $NewScriptsIniHash, '' ) | %{ $_ }) -join "`r`n" |
    Out-File -Encoding ASCII -FilePath $ScriptsIniPath -Force:$Force

  # ---- scripts.ini ----

  # ---- gpt.ini ----
  $Parent = Split-Path $GptIniPath -Parent
  mkdir $Parent -Force | Out-Null

  $GptIniContents = if ( Test-Path $GptIniPath ) {
    Write-Verbose "  $GptIniPath exists"
    cat $GptIniPath | %{
      if ( $Match = [Regex]::Match($_, '\s*Version\s*=\s*([0-9]+)\s*') ) {
        if ( $Match.Success ) {
          $n = [Int]($Match.Groups[1].Value) + 1
          Write-Verbose "    Bumping version from $($Match.Groups[1].Value) to $n"
          $_ = "Version=$n"
        }
      }
      Write-Output $_
    }
  }
  else {
    Write-Verbose "  $GptIniPath does not exist. Creating anew .."
    @"
[General]
gPCMachineExtensionNames=[{42B5FAAE-6536-11D2-AE5A-0000F87571E3}{40B6664F-4972-11D1-A7CA-0000F87571E3}]
Version=2
"@
  }

  Write-Verbose "Writing out gpt.ini file ($GptIniPath)."
  ($GptIniContents -join "`r`n") | Out-File -Encoding ASCII -FilePath $GptIniPath -Force
  # ---- gpt.ini ----

  # ---- Reg File ----
  Write-Verbose "Creating startup .reg file"

  $RegFileContents = @"
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon]
"HideStartupScripts"=dword:00000000
"RunStartupScriptSync"=dword:00000001

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion]

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy]

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State]

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine]

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts]

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Shutdown]

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup]

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\$($TargetKey.MajorKey)]
"GPO-ID"="LocalGPO"
"SOM-ID"="Local"
"FileSysPath"="%SystemRoot%\\System32\\GroupPolicy\\Machine"
"DisplayName"="Local Group Policy"
"GPOName"="Local Group Policy"
"PSScriptOrder"=dword:00000001

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Startup\$($TargetKey.MajorKey)\$($TargetKey.MinorKey)]
"Script"="$ScriptPathEscaped"
"Parameters"="$ScriptParametersEscaped"
"ExecTime"=hex(b):00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy]

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts]

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown]

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup]

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\$($TargetKey.MajorKey)]
"GPO-ID"="LocalGPO"
"SOM-ID"="Local"
"FileSysPath"="%SystemRoot%\\System32\\GroupPolicy\\Machine"
"DisplayName"="Local Group Policy"
"GPOName"="Local Group Policy"
"PSScriptOrder"=dword:00000001

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Startup\$($TargetKey.MajorKey)\$($TargetKey.MinorKey)]
"Script"="$ScriptPathEscaped"
"Parameters"="$ScriptParametersEscaped"
"IsPowershell"=dword:00000000
"ExecTime"=hex(b):00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
"@

  $RegFileContents | Out-File -Encoding ASCII -FilePath $RegFile -Force
  Write-Verbose "  Attempting to import Regfile '$RegFile'"
  try {
    Write-Verbose "  reg.exe import $RegFile"
    # regedit.exe /s $RegFile
    # Also fails under non-english locales
    reg.exe import $RegFile | Write-Verbose # # Note : This always exits with a non-zero, ugh, why??
  }
  catch {
    if ( $_ -imatch 'The operation completed successfully.' ) {
      Write-Verbose "  Successfully imported '$RegFile' : $_ (Ignoring exception)"
    }
    else {
      notepad $RegFile
      Throw "    Error importing '$RegFile' : $_"
    }
  }
  finally {
    # notepad $RegFile # -Force:$Force -Verbose:$VerbosePreference
    rm $RegFile -Force:$Force -Verbose:$VerbosePreference
  }
  # ---- Reg File ----
<#
.SYNOPSIS
Add a machine startup script in the group policy machine startup section.

.DESCRIPTION
WARNING:  This function is not versatile for all use cases and so is limited and may contain bugs.
USE WITH CAUTION.

This function creates the appropriate registry keys and bindings in the group policy script definition files.

#>
}

function Uninstall-StartupCommand {             #M:UserLogon
  [CmdletBinding()] Param(
    [ Parameter( Position=0, Mandatory=$True, ValueFromPipeline=$True,
      ValueFromPipelineByPropertyName=$True ) ]
      [System.Management.ManagementBaseObject]$Command,
      [Switch]$Force
  )
  begin {}
  process {
    Write-Verbose "Location $($Command.Location) ... "
    if ( $Command.Location -imatch 'Startup' ) {
      Write-Verbose "Uninstalling Startup command $($Command.Location)\$($Command.Command) for user $($Command.User)"
      Write-Verbose "  User: $_"

      $ProfileDir = Get-User -UserNameRegex ($Command.User -replace ".*\\","") | %{
        $User=$_; Gwmi Win32_UserProfile | ?{ $User.SID -eq $_.SID } | %{$_.LocalPath}
      }

      # TODO: This needs to deduced not inferred.
      $StartupDir = [Environment]::GetfolderPath('Startup')
      $StartupDir = $StartupDir.SubString( ($Env:USERPROFILE).Length + 1 )

      $Script = "{0}\{1}\{2}" -f $ProfileDir, $StartupDir, $Command.Command

      if ( Test-Path $Script ) {
        Write-Verbose "Script found '$Script' .. removing"
        rm $Script -Force:$Force
      }
      else {
        Write-Warning "Script not found '$Script' $($Command.Location)\$($Command.Command)"
      }
    }
    elseif ( $_.Location -imatch '^HK' ) {
      Remove-ItemProperty -Path "Registry::$($Command.Location)" -Name $Command.Name `
                          -Verbose:$VerbosePreference -ea 1
      #Write-Verbose "  reg.exe delete $($Command.Location) /v $($Command.Name) /f"
      #reg.exe delete "$($Command.Location)" /v "$($Command.Name)" /f  | Write-Verbose
    }
    else {
      Write-Warning "Uninstall not implemented for location '$($Command.Location)' ($($Command.Command))"
    }
  }
  end{}
}

function Install-UserStartupScript {
  [CmdletBinding()] Param(
      [Regex]$Script
    )

# Generate a .cmd file to get around the default execution policy restrictions
# Powershell is invoked with the execution policy temporarily set to bypass
# The default is restored upon process completion.
$CmdScriptLet = @"
@echo off
set THISDIR=%~dp0
set WRAPPEDCMD=%THISDIR%\${Script}

cd %THISDIR%
if exist %WRAPPEDCMD% (
  powershell.exe -nologo -noprofile -executionpolicy bypass -command %WRAPPEDCMD%
)
if not exist %WRAPPEDCMD% ( del /f /q %WRAPPEDCMD%  )
"@

$CmdScriptLet
#$LogonScript = (Join-Path $ThisDir "${Script}.cmd")
  # $Script | Out-File -Encoding ASCII $LogonScript
}

function Get-StartupCommand {                   #M:UserLogon
  [CmdletBinding()] Param(
    [Regex]$Key,
    [Regex]$Value
  )

  $StartupCommand = gwmi Win32_StartupCommand

  if ( $Key -and $Value ) {
    $TargetKeys = & ($MyInvocation.MyCommand.Name) -Key $Key | %{ $_.Name }
    $StartupCommand | ? {
      $Command = $_; $Match = $False;
      $TargetKeys | %{
        if ($Command.($_) -imatch ([String]$Value)) {
          $Match = $True
        }
      }
      $Match
    }
  }
  elseif ( $Key ) {
    # Filter out properties beginning with _
    $StartupCommand | gm | ?{
      ($_.MemberType -eq "Property") -and ($_.Name -inotlike "_*") -and ($_.Name -imatch ([String]$Key))
    }
  }
  elseif ( $StartupCommand ) {
    $StartupCommand
  }
}

function Set-FirstLogonAnimations {         #M:UserLogon
  [CmdletBinding()] Param(
    [Switch] $Enable
  )
  Write-Verbose "Setting First Logon Animations ($Enable)"
  if ( (Get-Win32_OperatingSystem).Version -ge 6.2 ) { # > Windows 8
    & reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"  /v "EnableFirstLogonAnimation" /t REG_DWORD  /d ([Int][Boolean]$Enable) /f | Write-Verbose
    & reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"      /v "EnableFirstLogonAnimation" /t REG_DWORD  /d ([Int][Boolean]$Enable) /f | Write-Verbose
  }
  elseif ( (Get-Win32_OperatingSystem).Version -le 5.1 ) { # Windows XP
    & reg.exe add "HKLM\Software\Microsoft\Windows NT\Current Version\WinLogon" /v  "LogonType" /t REG_DWORD  /d ([Int][Boolean]$Enable) /f | Write-Verbose
  }
}

function Enable-FirstLogonAnimations {         #M:UserLogon
  [CmdletBinding()] Param() Set-FirstLogonAnimations -Enable
}

function Disable-FirstLogonAnimations {         #M:UserLogon
  [CmdletBinding()] Param() Set-FirstLogonAnimations -Enable:$False
}

function Disable-ScreenSaver {                  #M:DesktopUtils
  [CmdletBinding()] Param()
  Write-Verbose "Disabling the ScreenSaver"
  # TODO. Need to figure out how this might be applied to all users
  #  Group Policy?
  & reg.exe add "HKCU\Control Panel\Desktop" /v ScreenSaveActive /t REG_SZ /d 0 /f | Write-Verbose
}

function Enable-ScreenSaver {                   #M:DesktopUtils
  [CmdletBinding()] Param()
  Write-Verbose "Enabling the ScreenSaver"
  # TODO. Need to figure out how this might be applied to all users
  #  Group Policy?
  & reg.exe add "HKCU\Control Panel\Desktop" /v ScreenSaveActive /t REG_SZ /d 1 /f | Write-Verbose
}

function Enable-ShowDesktopOnLogon {            #M:DesktopUtils
  [CmdletBinding()] Param()
  Write-Verbose "Adding Show-Desktop.cmd as a logon task"

  $local:taskName = "ShowDesktopOnLogon"

$local:cmd=@"
@echo off
:: CLSID of "Show Desktop"
explorer.exe "shell:::{3080F90D-D7AD-11D9-BD98-0000947B0257}"
"@

  $cmd | Out-File -ea 0 -Encoding ascii ($local:showDesktopCmd = Join-Path $Env:WINDIR "System32\Show-Desktop.cmd")
  Install-GlobalLogonScript $showDesktopCmd "Show-Desktop.cmd";

$scf=@"
[Shell]
Command=2
IconFile=Explorer.exe,3
[Taskbar]
Command=ToggleDesktop
"@

  $scf | Out-File -ea 0 -Encoding ascii ($local:showDesktopCmd = Join-Path $Env:WINDIR "System32\Show-Desktop.scf")
  Install-GlobalLogonScript $showDesktopCmd "Show-Desktop.scf";

  # & schtasks /create /TN "ShowDesktopOnWinlogon" /TR $showDesktopCmd /SC ONEVENT /EC System /MO *[System/EventID=7001] /f  # EventID 7001=Winlogon logon event
  # & schtasks /create /TN ShowDesktopOnLogon /SC ONLOGON /F /TR $showDesktopScf /f
}

function Install-SendToShortcut {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)]
      $Command
  )
  $Command | %{
    Write-Verbose "Adding SendTo shortcut to '$_'"
    $target=$_

    (Join-Path $Env:USERPROFILE "AppData\Roaming\Microsoft\Windows\SendTo"),
    (Join-Path $Env:USERPROFILE "SendTo") | %{
        $linkPath = Join-Path $_ "$target.lnk"
        Write-Verbose "  $linkPath"
        $link            = (New-Object -ComObject WScript.Shell).CreateShortcut($linkPath)
        $link.TargetPath = "$target.exe"
        $link.Save()
    }
  }
}

function Install-DesktopShortcut {              #M:DesktopUtils
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)]
      $Command,
      $Label = $Command
  )

  if ( -not(gcm $Command) -and -not(Test-Path $Command) ) {
    Throw "Command '$Command' does not exist."
  }

  $dirs =
    (Join-Path $Env:ALLUSERSPROFILE "Desktop"),
    (Join-Path $Env:USERPROFILE     "AppData\Roaming\Microsoft\Internet Explorer\Quick Launch"),
    (Join-Path $Env:USERPROFILE     "Application Data\Microsoft\Internet Explorer\Quick Launch")

  Write-Verbose "Adding desktop shortcut '$Label' to '$Command'"
  $target = ($Command -split "\\")[-1]
  $linkName = "${Label}.lnk"

  foreach ($dir in $dirs) {
    $linkPath = Join-Path $dir $linkName
    if ( Test-Path $dir ) {
      Write-Verbose "  $linkPath"
      $WSShell                = New-Object -ComObject WScript.Shell
      $link                   = $WSShell.CreateShortcut($linkPath)
      # This is a literal and not expanded as it is to be installed in the all-users dir
      # $link.WorkingDirectory  = $WSShell.ExpandEnvironmentStrings('%USERPROFILE%')
      $link.WorkingDirectory  = '%USERPROFILE%'
      $link.WindowStyle       = 1
      $link.Description       = $Label
      $link.TargetPath        = $Command
      # TODO, save() seems to break under some localized OSes
      # Error invoking save with 0 arguments, "??? ????? ????"
      $link.Save()
    }
  }

  $shell = New-Object -ComObject Shell.Application
  $desktopFolder = $shell.Namespace( (Join-Path $Env:ALLUSERSPROFILE "Desktop") )
  if ( $pinVerb = $desktopFolder.ParseName( $linkName ).verbs() | ?{ $_.Name -imatch "Pin To Tas.kbar"} ) {
    Write-Verbose "Pinning $Command to the taskbar"
    $pinVerb.DoIt()
  }

}

function Disable-ServerManager {                #M:DesktopUtils
  [CmdletBinding()] Param()
  Write-Verbose "Disabling Server Manager"
  if (Test-Path "HKLM:\SOFTWARE\Microsoft\ServerManager") {
    & reg.exe add "HKLM\SOFTWARE\Microsoft\ServerManager" /f  /v  "DoNotOpenServerManagerAtLogon" /t REG_DWORD  /d 0x1 | Write-Verbose
    & reg.exe add "HKCU\Software\Microsoft\ServerManager" /f  /v  "CheckedUnattendLaunchSetting"  /t REG_DWORD  /d 0x0 | Write-Verbose
  }
}

function Get-TimeZone {                         #M:TimeUtils
  [CmdletBinding()] Param(
    [String]$TimeZoneName,
    [Switch]$LocalTimeZone,
    [Switch]$UTC,
    [String]$SearchString
  )

  if ($SearchString) {
    $NameKeys = (Get-TimeZone)[0] | gm | ?{ $_.MemberType -eq "Property" -and $_.Name -imatch "^.*Name$|^Id$" } | %{ $_.Name }
    Get-TimeZone | ?{
      $This = $_
      $NameKeys | %{ if ($This.$_ -imatch $SearchString) { return $This } }
    }
  } elseif ($LocalTimeZone) {
    [TimeZoneInfo]::Local
  } elseif ($UTC) {
    [TimeZoneInfo]::Utc
  } elseif ($TimeZoneName) {
    # Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Time Zones" -Name
    [TimeZoneInfo]::FindSystemTimeZoneById($TimeZoneName)
  } else {
    [TimeZoneInfo]::GetSystemTimeZones()
  }
}

function Set-TimeZone {                         #M:TimeUtils
  [CmdletBinding()] Param(
    [Parameter(
        Position=0, Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True
      ) ]
    [Alias('TimeZone')] [TimeZoneInfo]$TimeZoneInfoObject,
    [Switch]$DSTOff
  )
  Begin {
    $OSVersion = ([Int]((Get-Win32_OperatingSystem).Version -replace "\.\d{3,}$"))
  }
  Process {
    $TimeZoneName = $TimeZoneInfoObject.ID
    Write-Verbose "Setting TimeZone to '$TimeZoneName', DSTOff: $DSTOff"
    Write-Verbose $TimeZoneInfoObject

    try {
      if ($OSVersion -ge 6.0) { # >= Vista
        gcm tzutil.exe    | Out-Null
      } else {
        gcm tzchange.exe  | Out-Null
      }
    } catch {
      throw "No TZ change tools (tzutil or tzchange) detected. OS Version = $OSVersion. $_"
    }

    if ($DSTOff) {
      if ($OSVersion -ge 6.0) { # >= Vista
        & tzutil.exe /s "${TimeZoneName}_dstoff"
      } else { # <= XP
        & tzchange.exe /C $TimeZoneName
      }
    } else {
      if ( $OSVersion -ge 6.0 ) { # >= Vista
        & tzutil.exe /s $TimeZoneName
      } else { # <= XP
        # & (Join-Path $Env:WINDIR "System32\Control.exe") "TIMEDATE.CPL,,/Z $TimeZoneName"
        & tzchange.exe /C $TimeZoneName
      }
    }
    & w32tm.exe /config /update             | Write-Verbose
  }
}

function Get-NTPServers {                       #M:TimeUtils
  [CmdletBinding()] Param()
  Get-RegKey "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DateTime\Servers" |
    ?{ $_.Property -ne "(default)" } | %{$_.value}
}

function Set-NTPServers {                       #M:TimeUtils
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)]  [String[]]$peerList
  )

  Write-Verbose "Setting NTP Parameters"
  Get-Service "W32Time" | Restart-Service
  if ( (Get-Win32_OperatingSystem).Version -lt 6 ) { # XP & 2003
    & w32tm /config /syncfromflags:MANUAL /manualpeerlist:$($peerList -join ",") /update
  }
  else {
    & w32tm /config /syncfromflags:MANUAL /manualpeerlist:$($peerList -join ",") /reliable:yes /update
  }
  $c = 0
  $peerList | ?{ -not($_ -imatch "^[0-9]+x[0-9]") } | %{
    & reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DateTime\Servers"  /v $(++$c;$c)  /t REG_SZ  /d $_  /f | Write-Verbose
  }
  & w32tm /resync /rediscover
}

function Show-W32TmStatus {                     #M:TimeUtils
  [CmdletBinding()] Param(
    [switch]$Source,
    [switch]$Status,
    [switch]$Peers,
    [switch]$Configuration,
    [switch]$All
  )
  if ($All -or $Source) {
    Write-Verbose "Showing w32tm source"
    & w32tm /query /source
  }
  if ($All -or $Status) {
    Write-Verbose "Showing w32tm status"
    & w32tm /query /status
  }
  if ($All -or $Peers) {
    Write-Verbose "Showing peers"
    & w32tm /query /peers
  }
  if ($All -or $Configuration) {
    Write-Verbose "Showing configuration"
    & w32tm /query /configuration
  }
}

function Sync-W32Time {                         #M:TimeUtils
  [CmdletBinding()] Param(
    [String][ValidateSet('NTP','Domain')] $TimeSource = 'NTP'
  )
  Write-Verbose "Syncing W32time against '$TimeSource' ..."
  Get-Service "W32Time" | Restart-Service -Verbose
  if ( $TimeSource -imatch 'Domain' ) {
    gwmi Win32_NetworkAdapterConfiguration | ?{ $_.DNSDomain } | %{
      & net.exe time /domain:$($_.DNSDomain) /set /yes | Write-Verbose
    }
  } else {
    & w32tm.exe /resync /rediscover /nowait | Write-Verbose
  }
  Show-W32TmStatus -Status
}

function Get-ISO8601TimeStamp {                 #M:TimeUtils
  [CmdletBinding()] Param(
    [Switch]$TimeStamp,
    [Switch]$TimeStampHiRes,
    [Switch]$DateStamp,
    [Switch]$DateWithWeekNumber,
    [Switch]$OrdinalDate,
    [Switch]$Compact
  )

  $Now           = [System.DateTime]::Now
  $OffsetFromUTC = $Now - [System.DateTime]::UtcNow
  $OffsetFromUTC = [Int]($OffsetFromUTC.Hours + $OffsetFromUTC.Minutes)
  $TimeZoneDesignator = if ( $OffsetFromUTC -eq 0 ) {
    "Z"
  } else {
    if ($OffsetFromUTC -gt 0) { "+$($OffsetFromUTC)" } else { [String]$OffsetFromUTC }
  }

  $Result = if ( $TimeStamp ) {
    Get-Date -UFormat "%Y-%m-%dT%H:%M:%S$TimeZoneDesignator"
  }
  elseif ( $TimeStampHiRes ) {
    Get-Date -UFormat "%Y-%m-%dT%H:%M:%S.$((Get-Date).MilliSecond)$TimeZoneDesignator"
  }
  elseif ( $DateStamp ) {
    Get-Date -UFormat "%Y-%m-%d"
  }
  elseif ( $DateWithWeekNumber ) {
    # TODO, Week 53 could span into the next year, this does not accomodate that
    #   e.g. "Sunday 3 January 2010" = "2009-W53-7"
    Get-Date -UFormat "%Y-W%V-$([Int](Get-Date).DayOfWeek)"
  }
  elseif ( $OrdinalDate ) {
    Get-Date -UFormat "%Y-$([Int](Get-Date).DayOfYear)"
  }

  $Result = if ( -not($Result) ) { Get-Date -UFormat %s } else { $Result }

  return ($_ = if ( $Compact ) { $Result -replace '[-:]','' } else { $Result })
}

function Enable-WinRM {
  [CmdletBinding()] Param(
  )

  winrm quickconfig -q
  winrm quickconfig -transport:http

  winrm set winrm/config              '@{MaxTimeoutms="1800000"}'
  winrm set winrm/config/winrs        '@{MaxMemoryPerShellMB="300"}'
  winrm set winrm/config/service      '@{AllowUnencrypted="true"}'
  winrm set winrm/config/service/auth '@{Basic="true"}'
  winrm set winrm/config/client/auth  '@{Basic="true"}'
  winrm set winrm/config/listener?Address=*+Transport=HTTP '@{Port="5985"}'

  netsh advfirewall firewall set rule group="remote administration" new enable=yes
  netsh firewall add portopening TCP 5985 "Port 5985"

  Get-Service winrm | Set-Service -StartupType Manual -PassThru | Restart-Service
}

function Set-ProcessPriority {
  [CmdletBinding()] Param(
    [Int32] $Id,
    [System.Diagnostics.ProcessPriorityClass] $Priority
  )
  Get-Process -Id $Id | %{ $_.PriorityClass = $Priority }
  Gwmi Win32_Process -Filter "ProcessId = '$Id'" | %{ $_.SetPriority( $Priority.Value__ ) }
}

function Find-String {
  [CmdletBinding()] Param(
    [Regex]       $Pattern,
    [IO.FileInfo] $File
  )
  cat $File | ?{ $_ -imatch $Pattern }
}

Set-Alias grep      Find-String
Set-Alias reboot    Restart-Computer
Set-Alias poweroff  Stop-Computer

Export-ModuleMember -Function * -Alias * -Variable Win32*
