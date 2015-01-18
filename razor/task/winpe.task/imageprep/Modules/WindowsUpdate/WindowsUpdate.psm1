#
# WindowsUpdate.psm1

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
    [Switch] $AutoInstallMinorUpdates = $False,
    [Switch] $NoAutoRebootWithLoggedOnUsers = $True,
    [Switch] $StartWindowsUpdateService = $True
  )
  Write-Verbose "Enabling Windows Updates"
  & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AutoInstallMinorUpdates       /t REG_DWORD /d ([Int][Boolean]$AutoInstallMinorUpdates) /f | Write-Verbose
  & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d ([Int][Boolean]$NoAutoRebootWithLoggedOnUsers) /f | Write-Verbose
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
  Get-Service wuauserv | Set-Service -StartupType $StartupType -Verbose:$VerbosePreference -PassThru | Stop-Service -Verbose:$VerbosePreference
<#
.SYNOPSIS
Set the windows update service startup type to be manual (not automatic).

.DESCRIPTION
Set the windows update service startup type to be manual (not automatic).

.PARAMETER StartupType
Set the windows update service startup type to be one of Manual (default) or Disabled.
#>
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
    $Result | Add-Member NoteProperty "GP$($_.Name)" $AuPolicy.($_.Name) -Force
  }

  $Result

<#
.SYNOPSIS
List setting related to the windows update service.
#>
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

function Search-WindowsUpdate {
  [CmdletBinding()] Param(
    [switch]$ImportantOnly,
    [switch]$All,
    [switch]$History
  )

  Write-Verbose $MyInvocation.MyCommand
  Write-Verbose "  -ImportantOnly : $ImportantOnly"
  Write-Verbose "  -All           : $All"

  if ($ImportantOnly -and $All) {
    # TODO : Use parameter sets to set exclusivity
    Throw "ERROR: The switches -ImportantOnly and -All are mutually exclusive."
  }

  $Global:UpdateSession = New-Object -ComObject Microsoft.Update.Session
  $updateSearcher = $Global:UpdateSession.CreateupdateSearcher()

  if ($History) {
    Write-Verbose "Listing History ..."
    return ($updateSearcher.QueryHistory(1, $updateSearcher.GetTotalHistoryCount()))
  }

  Write-Verbose "Searching for updates ..."
  $searchString = "IsInstalled=0 and IsAssigned=1"
  if (-not($All)) { $searchString += " and AutoSelectOnWebSites=1" } # Install ImportantOnly by default
  Write-Verbose "searchString : $searchString"
  $SearchResult = $updateSearcher.Search($searchString)

  Write-Verbose "Number of updates found: $($SearchResult.Updates.Count)"

  return $SearchResult.Updates

<#
.SYNOPSIS
Search for available windows updates.

.DESCRIPTION
Search for available windows updates.

.PARAMETER ImportantOnly
Search for and return important updates only.

.PARAMETER All
Search and return All windows updates.

.PARAMETER History
Search for and return the updates that were previously applied.

.EXAMPLE
$AvailableUpdates = Search-WindowsUpdate -ImportantOnly
$AvailableUpdates | Install-WindowsUpdate
#>

}

function Install-WindowsUpdate {
  [CmdletBinding()] Param(
    [Switch]$DownloadOnly,
    [Parameter(Position=0, Mandatory=$False, ValueFromPipeline=$True)] $SearchResult
  )

  begin {
    Write-Verbose $MyInvocation.MyCommand
    Write-Verbose "  -DownloadOnly  : $DownloadOnly"
    $updatesToInstall  = New-Object -ComObject Microsoft.Update.UpdateColl
    $Global:candidatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
  }

  process {
    if ($SearchResult.InstallationBehavior.CanRequestUserInput) {
      Write-Host -ForegroundColor Magenta "Update requires user input: " $SearchResult.Title
      $SearchResult | fl *
    }
    else {
      $IsInstalled = $SearchResult.IsInstalled
      $IsDownloaded = $SearchResult.IsDownloaded
      Write-Verbose   " Candidate: $($SearchResult.Title)"
      Write-Verbose   "   IsInstalled: $IsInstalled"
      Write-Verbose   "   IsDownloaded: $IsDownloaded"
      if (-not($IsInstalled)) { $updatesToInstall.Add( $SearchResult ) > $Null }
    }
  }

  end {
    if ( -not($updatesToInstall.Count) ) {
      Write-Verbose "$($updatesToInstall.Count) candidates to install. Exiting."
      return
    }

    $updatesToInstall | ?{ -not($_.IsDownloaded) } | % { $Global:candidatesToDownload.Add($_) > $Null}

    if ($Global:candidatesToDownload.Count) {
      $downloader         = $Global:UpdateSession.CreateUpdateDownloader()
      $downloader.Updates = $Global:candidatesToDownload
      try {
        Write-Verbose "Downloading $($updatesToInstall.Count) updates ..."
        $downloader.Download() > $Null
        Write-Verbose "Downloads complete."
      }
      catch {
        Write-Verbose "Problem downloading updates." $_
        Write-Verbose " " $error[0]
      }
    }

    if ($DownloadOnly) {
      Write-Verbose "-DownloadOnly ($DownloadOnly) requested, returning .."
      return $updatesToDownload
    }


    Write-Verbose "Candidates to install: $($updatesToInstall.Count)"
    $i=0; $updatesToInstall | %{
      Write-Verbose "  * $($i++) $($_.Title)";
      $_.AcceptEula()
    }

    Write-Verbose "Setting update installer preferences for automation ..."
    $installer                    = $Global:UpdateSession.CreateUpdateInstaller()
    $installer.Updates            = $updatesToInstall
    $installer.AllowSourcePrompts = $false
    $installer.ForceQuiet         = $true

    Write-Verbose "Installing $($updatesToInstall.Count) updates ..."
    $installationResult = $installer.Install()

    Write-Verbose "Installation Result: $($installationResult.Resultcode)"
    Write-Verbose "Reboot Required: $($installationResult.RebootRequired)"

    return $installationResult
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
    [Switch] $RebootIfNecessary
  )

  Write-Verbose "Installing important windows updates"
  Enable-WindowsUpdate

  $UpdateResults = @()
  $Count = 0

  while ($UpdateCollection = Search-WindowsUpdate -ImportantOnly -Verbose:$VerbosePreference) {
    if ( $UpdateResult = $UpdateCollection | Install-WindowsUpdate -Verbose:$VerbosePreference ) {
      $UpdateResults += $UpdateResult

      $Result = "  Count: {0}, ResultCode: {1}, RebootRequired: {2}" `
                  -f $Count, $UpdateResult.ResultCode, $UpdateResult.RebootRequired
      Write-Verbose $Result

      if ( (([Boolean]($UpdateResult.RebootRequired)) -and $RebootIfNecessary) -or ($Count -ge 5) ) {
        Restart-Computer
      }

      $Count++
    }
  }

  Disable-WindowsUpdate
  return $UpdateResults

<#
.SYNOPSIS
Convenience function to search for and install important windows update.

.DESCRIPTION
Convenience function to search for and install important windows update.
This function effectively calls
Search-WindowsUpdate -ImportantOnly | Install-WindowsUpdate

.PARAMETER RebootIfNecessary
Reboot the machine any updates require a reboot to be effectively applied.
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
