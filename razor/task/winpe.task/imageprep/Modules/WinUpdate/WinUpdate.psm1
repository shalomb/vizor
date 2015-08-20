#
# WinUpdate.psm1

$ErrorActionPreference = "STOP"
Set-StrictMode -Version 2.0

$Global:UpdateSession = $Null # Scoped global: (not script:) to overcome piping issues with COM objects

# TODO
# # Configure policy settings, frequencies, reboot policies, etc
# http://technet.microsoft.com/en-us/library/cc708449(v=ws.10).aspx
# http://technet.microsoft.com/en-gb/library/dd939844(v=ws.10).aspx
# http://smallvoid.com/article/winnt-automatic-updates-config.html

function Enable-WindowsUpdate {
  [CmdletBinding()] Param(
    [ValidateSet('Manual','Automatic')]
      [String]  $StartupType = 'Manual',
    [Switch] $StartWindowsUpdateService = $True
  )

  Write-Verbose "Enabling Windows Updates"

  if ($StartWindowsUpdateService) {
    Get-Service wuauserv |
      Set-Service -StartupType $StartupType -Verbose:$VerbosePreference -PassThru |
      Restart-Service -Verbose:$VerbosePreference
  }
<#
.SYNOPSIS
Enable the windows update service and start it if required.

.DESCRIPTION
Enable the windows update service and start it if required.

.PARAMETER StartupType
Set the windows update service startuptype - can be one of Manual (default) or Automatic.

.PARAMETER AutoInstallMinorUpdates
Allow the windows update service to automatically install minor update that do not require reboots.

.PARAMETER NoAutoRebootWithLoggedOnUsers
Do not reboot the machine if there are currently logged on users.

.PARAMETER StartWindowsUpdateService
Default is $True. If set to false, this just ensure that the registry entries to allow windows update to be enabled are set.
#>
}

function Disable-WindowsUpdate {
  [CmdletBinding()] Param(
    [ValidateSet('Manual','Disabled')]
      [String]  $StartupType = 'Manual'
  )
  Write-Verbose "Disabling Windows Updates"
  Get-Service wuauserv |
    Set-Service -StartupType $StartupType -Verbose:$VerbosePreference -PassThru |
    Stop-Service -Verbose:$VerbosePreference
<#
.SYNOPSIS
Set the windows update service startup type to be manual (not automatic).

.DESCRIPTION
Set the windows update service startup type to be manual (not automatic).

.PARAMETER StartupType
Set the windows update service startup type to be one of Manual (default) or Disabled.
#>
}

function Set-WindowsUpdatePreference {
  # KB328010
  # 'How to configure automatic updates by using Group Policy or registry settings'
  #   https://support.microsoft.com/en-us/kb/328010
  [CmdletBinding()] Param(
    [Switch] $AUDisabled,
    [Switch] $AUNotifyOfDownloadAndInstallation,
    [Switch] $AUDownloadAndNotifyOfInstallation,
    [Switch] $AUDownloadAndScheduleInstallation,
    [Switch] $AutoInstallMinorUpdates,
    [Switch] $ElevateNonAdmins,
    [Switch] $EnableFeaturedSoftware,
    [Switch] $IncludeRecommendedUpdates,
    [Switch] $NoAutoRebootWithLoggedOnUsers,
    [Switch] $NoAutoUpdate,
    [Switch] $UseWUServer
  )

  $AuOption = if     ($AUDisabled)                         { 1 }
              elseif ($AUNotifyOfDownloadAndInstallation)  { 2 }
              elseif ($AUDownloadAndNotifyOfInstallation)  { 3 }
              elseif ($AUDownloadAndScheduleInstallation)  { 4 }
              else                                         { $Null }

  if ( $AuOption ) {
    & reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" `
      /f /v AuOptions /t REG_SZ /d $AuOption | Write-Verbose
    & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
      /f /v AuOptions /t REG_SZ /d $AuOption | Write-Verbose
  }

  if ( $PSBoundParameters.ContainsKey('AutoInstallMinorUpdates') ) {
    & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
      /v AutoInstallMinorUpdates /t REG_DWORD /d ([Int][Boolean]$AutoInstallMinorUpdates)   /f | Write-Verbose
  }

  if ( $PSBoundParameters.ContainsKey('ElevateNonAdmins') ) {
    & reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" `
      /v ElevateNonAdmins        /t REG_DWORD /d ([Int][Boolean]$ElevateNonAdmins) /f | Write-Verbose
  }

  if ( $PSBoundParameters.ContainsKey('EnableFeaturedSoftware') ) {
    & reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" `
      /v EnableFeaturedSoftware        /t REG_DWORD /d ([Int][Boolean]$EnableFeaturedSoftware) /f | Write-Verbose
  }

  if ( $PSBoundParameters.ContainsKey('IncludeRecommendedUpdates') ) {
    & reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" `
      /v IncludeRecommendedUpdates /t REG_DWORD /d ([Int][Boolean]$IncludeRecommendedUpdates) /f | Write-Verbose
  }

  if ( $PSBoundParameters.ContainsKey('NoAutoUpdate') ) {
    & reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" `
      /v NoAutoUpdate /t REG_DWORD /d ([Int][Boolean]$NoAutoUpdate) /f | Write-Verbose
    & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
      /v NoAutoUpdate /t REG_DWORD /d ([Int][Boolean]$NoAutoUpdate) /f | Write-Verbose
  }

  if ( $PSBoundParameters.ContainsKey('UseWUServer') ) {
    & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
      /v UseWUServer /t REG_DWORD /d ([Int][Boolean]$UseWUServer) /f | Write-Verbose
  }

}

function Get-WindowsUpdateSettings {
  [CmdletBinding()] Param()

  Write-Verbose "Getting Windows Updates settings"
  $Result = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" | Select -Exclude PS* *

  $WUAuServ = Get-Service wuauserv
  $WUAuServRunning  = if ( $WUAuServ | ?{ $_.Status -eq 'Running' } ) { $True } else { $False }
  $WUAuServStatus   = $WUAuServ | %{ $_.Status }

  $Result =
  $Result | Add-Member -PassThru NoteProperty ServiceRunning  $WUAuServRunning -Force |
            Add-Member -PassThru NoteProperty ServiceStatus   $WUAuServStatus  -Force

  $AuPolicy = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" | Select -Exclude PS* *
  $AuPolicy | gm -MemberType NoteProperty | %{
    $Result | Add-Member NoteProperty "GP_$($_.Name)" $AuPolicy.($_.Name) -Force
  }

  $Result

<#
.SYNOPSIS
List setting related to the windows update service.
#>
}

function Get-WSUSClientSettings {
  [CmdletBinding()] Param()

  $Result = New-Object PSObject

  if ( Test-Path ($WURegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate") ) {
    $Result = Get-ItemProperty $WURegPath | Select -ExcludeProperty PS* *
  }

  if ( Test-Path ($WURegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU") ) {
    Get-ItemProperty $WURegPath | Select -ExcludeProperty PS* * | %{
      $Obj = $_
      $_ | gm -MemberType NoteProperty | Select -ExpandProperty Name | %{
        $Result | Add-Member NoteProperty $_ $Obj.($_) -Force
      }
    }
  }

  $Result
}

function Update-WUA {
  [CmdletBinding()] Param()

  $OS = Gwmi Win32_OperatingSystem

  # TODO, make this future proof, use the recommendations in
  #   'Updating Windows Update Agent (Windows)'
  #   https://msdn.microsoft.com/en-us/library/windows/desktop/aa387285%28v=vs.85%29.aspx
  if ( ($OS.Version -imatch '^6.1') ) { # Windows 7
    $PkgUrl = Switch -Regex ( $OS.OSArchitecture ) {
      '32-bit' { 'http://download.windowsupdate.com/windowsupdate/redist/standalone/7.6.7600.320/WindowsUpdateAgent-7.6-x86.exe' }
      '64-bit' { 'http://download.windowsupdate.com/windowsupdate/redist/standalone/7.6.7600.320/WindowsUpdateAgent-7.6-x64.exe' }
    }

    Install-Msu $PkgUrl -NoLog
  }
  elseif ( $OSVersion -imatch '6.2' ) { # Windows 8
    $PkgUrl = Switch -Regex ( $OS.Architecture ) {
      '32-bit' { 'http://download.microsoft.com/download/6/7/0/670287B4-32F0-458E-83AE-4316B0B1D0B8/Windows8-RT-KB2937636-x86.msu' }
      '64-bit' { 'http://download.microsoft.com/download/A/A/8/AA842D3A-D5B0-4307-89F1-3485D88A1853/Windows8-RT-KB2937636-x64.msu' }
    }
    Install-Msu $PkgUrl
  }
}

function Install-MSU {
  [CmdletBinding()] Param(
    [String] $Url,
    [String] $File,
    [String] $LogFile,
    [Switch] $NoLog
  )

  if ( $Url ) {
    if ( -not( Test-Path ($File = Join-Path $Env:TEMP (($Url -split '/')[-1])) ) ) {
      try {
        (New-Object Net.WebClient).DownloadFile($Url, $File)
      } catch {
        Throw "Failed to download '$Url' to '$File'"
      }
    }
  }

  if ( Test-Path ($File = (ls (Resolve-Path $File).Path)) ) {
    if ( $File -imatch 'msu$' ) {
      $Args = @($File, '/quiet', '/norestart')
      $LogFile = if ($LogFile) { $LogFile } else { Join-Path $Env:TEMP "$File.wusa.install.log" }
      if ( -not($NoLog) ) { $Args+=("/log:$LogFile") }

      Write-Verbose "Installing wusa.exe $File $Args"
      $Process = Start-Process 'wusa.exe' -ArgumentList $Args -NoNewWindow -Wait
    }
    elseif ( $File -imatch 'exe$' ) {
      $Args = @('/quiet', '/norestart','/wuforce')
      Write-Verbose "Installing '$File' $Args"
      $Process = Start-Process $File -ArgumentList $Args -NoNewWindow -Wait
    }
    else {
      Throw "No implementation exists to install update of type '$File'"
    }
  }
  else {
    Throw "File '$File' does not exist"
  }
}

function Set-WSUSServer {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)]
      [String] $WUServer,
    [Parameter(Mandatory=$False)]
      [String] $WUStatusServer = $WUServer,
    [Parameter(Mandatory=$False)]
      [Switch] $DoNotConnectToWindowsUpdateInternetLocations=$True
  )

  & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"    `
      /f /v WUServer       /t REG_SZ     /d $WUServer        | Write-Verbose
  & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"    `
      /f /v WUStatusServer /t REG_SZ     /d $WUStatusServer  | Write-Verbose
  & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
      /f /v UseWUServer    /t REG_DWORD  /d 0x1              | Write-Verbose
  & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"    `
      /f /v DoNotConnectToWindowsUpdateInternetLocations  /t REG_DWORD      `
      /d ([Int][Boolean]$DoNotConnectToWindowsUpdateInternetLocations) | Write-Verbose

<#
.SYNOPSIS
Configure the WSUS client to point at a given WSUS URL.

.DESCRIPTION
Configure the WSUS client to point at a given WSUS URL.

.PARAMETER WUServer
URL of the WUServer (No validation is performed).

.PARAMETER WUStatusServer
URL of the WUStatusServer (No validation is performed).

.PARAMETER DoNotConnectToWindowsUpdateInternetLocations
Instruct the WSUS client to never connect to locations other than the WSUS server.
#>
}

function Disable-WSUSServer {
  [CmdletBinding()] Param()

  & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" `
      /f /v UseWUServer    /t REG_DWORD  /d 0x0              | Write-Verbose
  & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"    `
      /f /v DoNotConnectToWindowsUpdateInternetLocations  /t REG_DWORD      `
      /d 0x0                                                 | Write-Verbose

<#
.SYNOPSIS
Disable the use of WSUS Server to provide Windows Update.

.DESCRIPTION
Disable the use of WSUS Server to provide Windows Update.
#>
}

function Get-WUAVersion {
  [CmdletBinding()] Param()

  $MUAInfo =  New-Object -ComObject Microsoft.Update.AgentInfo
  [version]($MUAInfo).GetInfo('ProductVersionString')
}

function Get-WindowsUpdateResults {
  [CmdletBinding()] Param()

  if ( Test-Path ($BasePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results") -ea 0 ) {
    $Result = New-Object PSObject

    try {
      $Detect   = gp (Join-Path $BasePath 'Detect')   | Select -Exclude PS* *
      $Detect   | gm -MemberType NoteProperty | %{ $Result | Add-Member NoteProperty "Detect$($_.Name)"   $Detect.($_.Name)   }
    } catch {}

    try {
      $Download = gp (Join-Path $BasePath 'Download') | Select -Exclude PS* *
      $Download | gm -MemberType NoteProperty | %{ $Result | Add-Member NoteProperty "Download$($_.Name)" $Download.($_.Name) }
    } catch {}

    try {
      $Install  = gp (Join-Path $BasePath 'Install')  | Select -Exclude PS* *
      $Install  | gm -MemberType NoteProperty | %{ $Result | Add-Member NoteProperty "Install$($_.Name)"  $Install.($_.Name)  }
    } catch {}

    $Result | gm -MemberType NoteProperty | %{
      if ( $_.Name -imatch 'time$' ) {
        $Result | Add-Member NoteProperty ($_.Name) ([DateTime]$Result.($_.Name)) -Force
      }
    }

    $Result
  }
}

function Assert-IsKB898461Installed {
  [CmdletBinding()] Param()
  $HotFixID = "898461"
  if ( -not( Get-HotFix | ?{ $_.HotFixID -imatch $HotFixID } ) ) {
    $ErrMsg = "HotFix KB898461 not installed on the system.`n"                                    +
              "  In order for the WindowsUpdate module to function, this HotFix is required.`n"   +
              "  Please visit http://support.microsoft.com/kb/898461 for installation details.`n" +
              "    Note: You may use the Show-KB898461 cmdlet to launch the URL in the browser.`n"
    Write-Error $ErrMsg
    throw ($ErrMsg -split "\n")[0]
  }
<#
.SYNOPSIS
Assert that hotfix 898461 is installed on the system. This hotfix is necessary
for the new Windows Update mechanisms to function on Legacy Systems (Windows XP/2003).

.DESCRIPTION
Software update 898461 installs the files for the Package Installer for Windows version 6.1.22.4.
This update is required on Windows XP/Vista for the WindowsUpdate modules to function properly.

To install hotfix 898461, use the Get-KB898461HotFix and Install-KB898461HotFix functions.
#>
}

function Get-KB898461HotFix {
  [CmdletBinding()] Param(
    [String]$DownloadDirectory = $Env:TEMP,
    [Switch]$Force
  )
  $KB898461PackageUrl =
    "http://download.microsoft.com/download" +
    "/5/f/d/5fdc6240-2127-42b6-8e16-bab6171db233/WindowsXP-KB898461-x86-ENU.exe"

  $KB898461Package = Join-Path $DownloadDirectory "WindowsXP-KB898461-x86-ENU.exe"
  if ($Force) {
    rm $KB898461Package -Force -ea $VerbosePreference -Verbose:$VerbosePreference
  }

  Write-Verbose "Downloading $KB898461PackageUrl"
  Write-Verbose "  to $KB898461Package ... "
  (New-Object Net.WebClient).DownloadFile($KB898461PackageUrl, $KB898461Package)
  Write-Verbose "  download complete."

  if ( Test-Path $KB898461Package ) {
    return $KB898461Package
  }
  return $False

<#
.SYNOPSIS
  Retrieve the KB898461 HotFix Package for local installation
.DESCRIPTION
  KB898461 - Software update 898461 installs a permanent copy of the
  Package Installer for Windows version 6.1.22.4

  This HotFix is required for the WindowsUpdate module to function
  properly. This function downloads the package and returns the path
  of the downloaded file.
.URL
http://support.microsoft.com/kb/898461
http://osdir.com/ml/windows.unattended.cvs/2005-06/msg00017.html
http://sourceforge.net/apps/trac/unattended/browser/trunk/install/scripts/winxpsp3-extras.bat
#>
}

function Install-KB898461HotFix {
  [CmdletBinding()] Param(
    [String]$DownloadDirectory = $Env:TEMP,
    [String]$LogDir = $Env:TEMP,
    [Switch]$Force
  )
  $KB898461Package = Get-KB898461HotFix @PSBoundParameters # Propogate -Force as it is not bound
  $KB898461PackageInstallLog = Join-Path $LogDir (($KB898461Package -split "\\")[-1] + ".install.log")

  # $KB898461PackageInstallArgs = @("/quiet", "/progress", "/norestart", "/log:$KB898461PackageInstallLog")
  $KB898461PackageInstallArgs = @("/passive", "/norestart", "/log:$KB898461PackageInstallLog")
  Write-Verbose "Invoking '$KB898461Package $KB898461PackageInstallArgs' ..."
  $Proc = Start-Process -FilePath $KB898461Package -ArgumentList $KB898461PackageInstallArgs `
                        -Wait:1 -PassThru -NoNewWindow:1 -Verbose

  Write-Verbose "  Install complete : ExitCode $($Proc.ExitCode)"
  $Proc.ExitCode

<#
.SYNOPSIS
  Invokes Get-KB898461HotFix and installs the downloaded HotFix locally
#>
}

function Invoke-WUDependencyChecks {
  [CmdletBinding()] Param()
  $OSVersion = (gwmi Win32_OperatingSystem).Version
  Write-Verbose "OSVersion :$OSVersion"
  if ( $OSVersion -imatch "^5.1" ) { # xp
    Write-Verbose "OSVersion :$OSVersion"
    Assert-IsKB898461Installed
  }
  else {
    Write-Verbose "OSVersion :$OSVersion"
    Write-Verbose " No Checks needed yet."
  }
<#
.SYNOPSIS
Do some minimal assertions to ensure that the WindowsUpdate module
functionality can be exercised on an end-point.
#>
}

function Show-KB898461URLInBrowser {
  [CmdletBinding()] Param()
  Write-Verbose "Launching http://support.microsoft.com/kb/898461 in IE"
  $IE = New-Object -Com InternetExplorer.Application
  $IE.navigate2("http://support.microsoft.com/kb/898461")
  $IE.visible = $True
<#
.SYNOPSIS
Start Internet Explorer nagivating the page to download hotfix 898461.
See Assert-IsKB898461Installed for more information.
#>
}

function Show-WindowsUpdateSettingsDialog {
  [CmdletBinding()] Param()
  & WUAuclt.exe /ShowSettingsDialog
<#
.SYNOPSIS
Show the Windows Update settings dialog.
#>
}

function Show-WindowsUpdateFeaturedUpdatesBrowser {
  [CmdletBinding()] Param()
  & wuauclt.exe /showfeaturedupdates
}

function Show-WindowsUpdateBrowser {
  [CmdletBinding()] Param()
  & WUAuclt.exe /ShowWindowsUpdate

<#
.SYNOPSIS
Start Internet Explorer with the Windows Update page.
#>
}

function Show-FeaturedOptInDialog {
  [CmdletBinding()] Param()
  & WUAuclt.exe /ShowFeaturedOptInDialog
<#
.SYNOPSIS
Show the Windows Update Feature Opt-in dialog box.
#>
}

function Invoke-WindowsUpdateDetection {
  [CmdletBinding()] Param()
  & WUAuclt.exe /DetectNow
}

function Search-WindowsUpdate {
  # https://msdn.microsoft.com/en-gb/library/windows/desktop/aa386526(v=vs.85).aspx
  [CmdletBinding()] Param(
    # "(https://msdn.microsoft.com/en-us/library/windows/desktop/aa386526(v=vs.85).aspx)",
    #   Default is '(IsInstalled=0 AND IsHidden=0)'
    [String]$SearchCriteria = "(IsInstalled=0 AND IsHidden=0)",
    [Switch]$IncludeAutoSelected,
    [String]$ClientApplicationID,
    [Switch]$Online,
    [Switch]$History
  )

  # 'Windows Update Agent (WUA) API Reference (Windows)'
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa387292(v=vs.85).aspx
  $Global:UpdateSession = New-Object -ComObject Microsoft.Update.Session
  $UpdateSearcher = $Global:UpdateSession.CreateUpdateSearcher()

  if ($History) {
    Write-Verbose "Listing History ..."
    return ($UpdateSearcher.QueryHistory(1, $UpdateSearcher.GetTotalHistoryCount()))
  }

  # TODO. Define a parameter to select WSUS
  # $UpdateSearcher.ServerSelection = 2 #ssWindowsUpdate, conflicts with WSUS

  if ( $ClientApplicationID ) {
    $Global:UpdateSession.ClientApplicationID    = $ClientApplicationID
  }

  if ( $Online ) {
    $UpdateSearcher.Online = $True
  }

  # Should one update replace another
  $UpdateSearcher.IgnoreDownloadPriority = $False
  $UpdateSearcher.IncludePotentiallySupersededUpdates = $False

  if ($IncludeAutoSelected) {
    $SearchCriteria += " OR (IsInstalled=0 AND AutoSelectOnWebSites=1)"
  }

  Write-Verbose "Searching for updates : $SearchCriteria"
  $SearchResult = $UpdateSearcher.Search($SearchCriteria)

  Write-Verbose "Number of updates found: $($SearchResult.Updates.Count)"

  return $SearchResult.Updates

<#
.SYNOPSIS
Search for available windows updates.

.DESCRIPTION
Search for available windows updates.

.PARAMETER SearchCriteria
Set the criteria to be used by the WUA when searching for updates.

.PARAMETER History
Search for and return the updates that were previously applied.

.EXAMPLE
$AvailableUpdates = Search-WindowsUpdate -SearchCriteria '(IsInstalled=0)'
$AvailableUpdates | Install-WindowsUpdate
#>

}

function Install-WindowsUpdate {
  [CmdletBinding()] Param(
    [Switch]$DownloadOnly,
    [Parameter(Position=0, Mandatory=$True, ValueFromPipeline=$True)] $SearchResult
  )

  begin {
    $updatesToInstall  = New-Object -ComObject Microsoft.Update.UpdateColl
    $Global:updatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
  }

  process {
    if ($SearchResult.InstallationBehavior.CanRequestUserInput) {
      Write-Host -ForegroundColor Magenta "Update requires user input: " $SearchResult.Title
      $SearchResult | fl *
    }
    else {
      Write-Verbose   " Candidate: $($SearchResult.Title)"
      Write-Verbose   "   IsInstalled:  $($SearchResult.IsInstalled), IsDownloaded: $($SearchResult.IsDownloaded)"
      if (-not($SearchResult.IsInstalled)) { $updatesToInstall.Add( $SearchResult ) > $Null }
    }
  }

  end {
    $updatesToInstall | ?{ -not($_.IsDownloaded) } | % { $Global:updatesToDownload.Add($_) > $Null }

    if ($Global:updatesToDownload.Count) {
      $downloader          = $Global:UpdateSession.CreateUpdateDownloader()
      $downloader.IsForced = $True
      $downloader.Priority = 3
      $downloader.Updates  = $Global:updatesToDownload

      try {
        Write-Verbose "Downloading $($updatesToInstall.Count) updates ..."
        $downloader.Download() > $Null
        Write-Verbose "Downloads complete."
      }
      catch {
        Write-Warning "Problem downloading updates." $_
        Write-Warning " " $error[0]
      }
    }

    if ($DownloadOnly) {
      Write-Verbose "-DownloadOnly ($DownloadOnly) requested, returning .."
      return $updatesToDownload
    }

    Write-Verbose "Candidate updates to install: $($updatesToInstall.Count)"
    if ( $updatesToInstall.Count ) {
      $i=0; $updatesToInstall | %{
        Write-Verbose "  * $($i++) $($_.Title)";
        $_.AcceptEula()
      }

      Write-Verbose "Setting update installer preferences for automation ..."
      $installer                    = $Global:UpdateSession.CreateUpdateInstaller()
      $installer.AllowSourcePrompts = $False
      $installer.IsForced           = $True
      $installer.ForceQuiet         = $True
      $installer.Updates            = $updatesToInstall

      try {
        Write-Verbose "Installing $($updatesToInstall.Count) updates ..."
        $installationResult = $installer.Install()
        Write-Verbose "Installation Result: $($installationResult.Resultcode)"
        Write-Verbose "Reboot Required: $($installationResult.RebootRequired)"
        return $installationResult
      } catch {
        Write-Warning "Problem installing update: $_"
      }
    }
  }

<#
.SYNOPSIS
Install a collection of updates passed in via the pipeline.

.DESCRIPTION
Install a collection of updates (via Search-WindowsUpdate) passed in via the pipeline.
These can also be passed in via the $SearchResult parameter.

.PARAMETER SearchResult
A collection of windows updates as returned via Search-WindowsUpdate

.PARAMETER DownloadOnly
Download but do not apply windows update
#>

}

function Install-ImportantWindowsUpdates {
  [CmdletBinding()] Param(
    [Int32]  $WorkingSetSize    = 0x90,
    [Int32]  $NumberOfRounds    = 0x04,
    [Switch] $RebootIfNecessary = $True
  )

  Write-Verbose "Installing important windows updates"

  $UpdateResults = @()

  $i = 0; while ( $i -le $NumberOfRounds ) {

    if ( Get-WindowsUpdateSystemInfo -RebootRequired ) {
      Write-Warning "A pending reboot is required."
      if ( $RebootIfNecessary ) {
        Write-Warning "  Rebooting the computer .."
        Restart-Computer
      }
      else {
        Write-Warning "  ** WARNING, CONTINUING WITHOUT A REBOOT **"
      }
    }

    $UpdateResult = Search-WindowsUpdate -Verbose:$VerbosePreference | Select -First $WorkingSetSize |
           Install-WindowsUpdate -Verbose:$VerbosePreference

    if ( $UpdateResult -is [System.Object[]] ) {
      # TODO, this is a hack. Search-WindowsUpdate/Install-WindowsUpdate require refactoring.
      Write-Warning "Install-WindowsUpdate did not return an expected type. Aborting .."
      return $UpdateResults
    }

    if ( $UpdateResult ) {

      $UpdateResults += @( $UpdateResult )

      $HResult    = $UpdateResult.HResult
      $ResultCode = $UpdateResult.ResultCode
      # 'OperationResultCode enumeration (Windows)'
      #   https://msdn.microsoft.com/en-us/library/windows/desktop/aa387095(v=vs.85).aspx
      $ResultMessage = @{
        0 = 'NotStarted';
        1 = 'InProgress';
        2 = 'Succeeded';
        3 = 'SucceededWithErrors';
        4 = 'Failed';
        5 = 'Aborted';
      }

      $Result = "  i: {0}, ResultCode: {1} ({2}, {3}), RebootRequired: {4}" -f $i,
                    $ResultCode, $ResultMessage[$ResultCode], $HResult,
                    (Get-WindowsUpdateSystemInfo -RebootRequired)
      Write-Verbose $Result
    }
    else {
      return $UpdateResults
    }

    $i++
  }

  return $UpdateResults

<#
.SYNOPSIS
Convenience function to search for and install important windows updates.

.DESCRIPTION
This function attempts to install all important updates and tries to repeat
the process until there are no more updates to apply.
NOTE: If a reboot is required to continue, the computer will be rebooted and
no attempt to resume the process after rebooting is made. This may be done
even before any updates are applied.

.PARAMETER RebootIfNecessary
Reboot the machine if the Windows Update Agent (WUA) has a pending reboot.
This check is performed before updates are searched for or installed in a
round of applying updates.
If a reboot occurs, the update results collection is not returned.

.PARAMETER WorkingSetSize
Maximum number of updates to consider in one round of installing windows
updates. The higher the value, the longer the round takes (and may not
complete on older hardware). The shorter the value, the more the number
of windows update rounds (and possibly reboots) needed.

.PARAMETER NumberOfRounds
Number of times to search for and install updates if no reboots are needed.
#>

}


function Get-WindowsUpdateInstallerStatus {
  [CmdletBinding()] Param(
    [Switch] $IsBusy
  )

  $MicrosoftUpdateInstaller = New-Object -ComObject "Microsoft.Update.Installer"

  if ( $IsBusy ) {
    $MicrosoftUpdateInstaller.IsBusy
  }
  else {
    $MicrosoftUpdateInstaller
  }
  <#
  .SYNOPSIS
  Return the status of the microsoft update installer

  .PARAMETER IsBusy
  Indicate whether or not the microsoft update installer is processing updates.
  #>
}

function Get-WindowsUpdateSystemInfo {
  [CmdletBinding()] Param (
    [Switch] $RebootRequired
  )
  $SystemInfo = New-Object -ComObject "Microsoft.Update.SystemInfo"

  if ( $RebootRequired ) {
    $SystemInfo.RebootRequired
  }
  else {
    $SystemInfo
  }
<#
.SYNOPSIS
Return the Microsoft.Update.SystemInfo COM Object Collection.

.PARAMETER RebootRequired
Indicate whether or not a reboot of the machine is required to complete update application.
#>

}

function Get-WindowsUpdateHistory {
  [CmdletBinding()] Param()
  Search-WindowsUpdate -History

<#
.SYNOPSIS
Convenience function/alias for Search-WindowsUpdate -History
#>

}

# The following function is functionally incomplete and not tested.
function Resolve-KBByID {
  Param(
    [Parameter(Mandatory=$True)] $ID
  )

  if ( -not(Test-Path($BaseDir = Join-Path $Env:PROGRAMDATA 'Microsoft\Windows\WindowsUpdate\KBData')) ) {
    mkdir $BaseDir | Out-Null
  }

  if ($ID -imatch "^kb") {
    $ID = $ID -replace "^[Kk][Bb]", ""
  }

  $targetFile = Join-Path $BaseDir "kb${ID}.html"
  $kbUrl = "http://support.microsoft.com/kb/{0}/{1}" -f $ID, $Host.CurrentCulture

  if (-Not (Test-Path $targetFile)) {
    $webClient = New-Object System.Net.WebClient
    try {
      $webClient.DownloadFile($kbUrl, $targetFile)
    }
    catch {
      Write-Error "Error downloading '$url' to '$targetfile'"
      Write-Error $error
      return $False
    }
  }

  $html = ((cat $targetFile) -join "")

  $KbTitle = $MSBId = $KbDesc = $Revision = $DateCreated = $DateReviewed = $DateModified =
  $AppliesTo = $OSVersion = $Null

  [String] $KbTitle  = ([Regex]::Match($html, '<title>\s*(\S.*\S)\s*<\/title>')).Groups[1].Value
  [String] $KbTitle  = $KbTitle -replace '[\r\n\t]+',''

  [String]   $MSBId = ([Regex]::Match($KbTitle, '(MS\d+-\d+)\s*:')).Groups[1].Value
  $MSBUrl = if ($MSBId) {
    "http://technet.microsoft.com/en-gb/security/bulletin/$MSBID"
  } else { $Null }

  [String] $KbDesc   = ([Regex]::Match($html, '<meta name="Description" content="([^"]+)"')).Groups[1].Value
  [String] $KbDesc   = $KbDesc -replace '[\r\n\t]+',''

  try { [Version]  $Revision      = ([Regex]::Match($html,    'Revision:\s*([\d.]+)')).Groups[1].Value } catch {}
  try { [DateTime] $DateCreated   = ([Regex]::Match($KbTitle, ':\s*([^:]+\s*\d{2},\s*\d{4})\s*$')).Groups[1].Value } catch {}
  try { [DateTime] $DateReviewed  = ([Regex]::Match($html,    'Last Review:\s*([^-]+)')).Groups[1].Value } catch {}
  try { [DateTime] $DateModified  = ([Regex]::Match($html,    '<meta name="Search.DateModified" content="([^"]+)"')).Groups[1].Value } catch {}
  try { [String]   $AppliesTo     = ([Regex]::Match($html,    '(?i)Applies to<\/h5><ul>(.*?)<\/ul>[^>]+<\/div>')).Groups[1].Value } catch {}
  try { [String[]] $OSVersions    = [Regex]::Matches($AppliesTo, '<li>([^>]+)<\/li>') | %{ $_.Groups[1].Value } } catch {}

  $Result = New-Object PSObject
  $Result | Add-Member -PassThru NoteProperty KBID        "KB$ID"     |
            Add-Member -PassThru NoteProperty ArticleID   $ID         |
            Add-Member -PassThru NoteProperty Revision    $Revision   |
            Add-Member -PassThru NoteProperty DateCreated  $DateCreated |
            Add-Member -PassThru NoteProperty DateReviewed  $DateReviewed |
            Add-Member -PassThru NoteProperty DateModified  $DateModified |
            Add-Member -PassThru NoteProperty KBURL       $kbUrl      |
            Add-Member -PassThru NoteProperty MSBID       $MSBId      |
            Add-Member -PassThru NoteProperty MSBUrl      $MSBUrl     |
            Add-Member -PassThru NoteProperty Title       $KbTitle    |
            Add-Member -PassThru NoteProperty Description $KbDesc     |
            Add-Member -PassThru NoteProperty AppliesTo   $OSVersions |
            Add-Member -PassThru NoteProperty LocalFile   $targetFile

<#
.SYNOPSIS
Get some basic information about a KB by ID using the support.microsoft.com
webservice. WARNING: This function is not ready for production use.
#>
}

Export-ModuleMember *-*

#
# function List-InstalledHotFixes() {
#   Get-HoxFix
#   # Get-WMIObject -Class Win32_QuickFixEngineering
# }
