# Script Module VDIOptimizations/VDIOptimizations.psm1

# This Module performs some of the core optimizations as laid out in
# 'Windows 8 and Server 2012 Optimization Guide | Citrix Blogs'
#   http://blogs.citrix.com/2014/02/06/windows-8-and-server-2012-optimization-guide/

Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0

function Set-UserPreferences {                  #M:VDIOptimizations
  [CmdletBinding()]
  Param()
  Write-Verbose "Setting User Preferences"

  if (Test-Path ($profilesRoot = Join-Path $Env:SystemDrive "Users")) { # >= 6.0
    ; # ... do nothing, the assignment is done .. fall through
  }
  elseif (Test-Path ($profilesRoot = Join-Path $Env:SystemDrive "Documents and Settings")) {  # <= 5.1
    ; # ... do nothing, the assiment is done .. fall through
  }
  else {
    Throw "Error looking up the default user's profile."
  }

  if ( Test-Path ($defaultUserNTUSERDAT = ls -ErrorAction "SilentlyContinue" -Force (Join-Path $profilesRoot "Default*\NTUSER.DAT") 2> $Null | %{ $_.FullName }) ) {
    Write-Verbose "Loading '$defaultUserNTUSERDAT' into 'HKU:\dutemp'"

    $HKUDefaultUserTemp = "HKU\DefaultUserTempLoad\"
    & reg.exe load    $HKUDefaultUserTemp $defaultUserNTUserDat | Write-Verbose

    $HKUDefaultUserTemp, "HKCU\", "HKLM\" | %{
      $RegBasePath   = $_

      Write-Verbose "Making changes under the '$RegBasePath' registry path."
      & reg.exe add ( Join-Path $RegBasePath "Console" ) /f  /v "FaceName"               /t REG_SZ    /d "Lucida Console" | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Console" ) /f  /v "FontFamily"             /t REG_DWORD /d 0x36             | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Console" ) /f  /v "FontSize"               /t REG_DWORD /d 0xc0000          | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Console" ) /f  /v "FontWeight"             /t REG_DWORD /d 0x190            | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Console" ) /f  /v "HistoryBufferSize"      /t REG_DWORD /d 0x0400           | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Console" ) /f  /v "NumberOfHistoryBuffers" /t REG_DWORD /d 0x0008           | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Console" ) /f  /v "ScreenBufferSize"       /t REG_DWORD /d 0x270f0078       | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Console" ) /f  /v "WindowPosition"         /t REG_DWORD /d 0x0              | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Console" ) /f  /v "WindowSize"             /t REG_DWORD /d 0x00400090       | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Console" ) /f  /v "QuickEdit"              /t REG_DWORD /d 0x0              | Write-Verbose


      Write-Verbose "  Setting desktop parameters ..."
      & reg.exe add ( Join-Path $RegBasePath "Control Panel\Desktop" ) /f  /v "AutoEndTasks"         /t REG_SZ    /d 1    | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Control Panel\Desktop" ) /f  /v "DragFullWindows"      /t REG_SZ    /d 0    | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Control Panel\Desktop" ) /f  /v "MenuShowDelay"        /t REG_SZ    /d 10   | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Control Panel\Desktop" ) /f  /v "ScreenSaveActive"     /t REG_SZ    /d 0    | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Control Panel\Desktop" ) /f  /v "ScreenSaverIsSecure"  /t REG_SZ    /d 0    | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Control Panel\Desktop" ) /f  /v "ScreenSaveTimeOut"    /t REG_SZ    /d 0    | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Control Panel\Desktop" ) /f  /v "WaitToKillAppTimeout" /t REG_DWORD /d 8000 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Control Panel\Desktop" ) /f  /v "Wallpaper"            /t REG_SZ    /d "."  | Write-Verbose

      Write-Verbose "  Setting VM Image policy ..."
      & reg.exe add ( Join-Path $RegBasePath "Software\Image" ) /f /v "Revision" /t REG_SZ /d 1.0 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Image" ) /f /v "Virtual"  /t REG_SZ /d "Yes" | Write-Verbose

      Write-Verbose "  Setting desktop policy ..."
      & reg.exe add ( Join-Path $RegBasePath "Software\Microsoft\Feeds"                                         ) /f  /v  "SyncStatus"                 /t REG_DWORD    /d 0x0 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Microsoft\Windows\CurrentVersion\Applets\Tour"           ) /f  /v  "RunCount"                   /t REG_DWORD    /d 0x0 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"      ) /f  /v  "Hidden"                     /t REG_DWORD    /d 0x0 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"      ) /f  /v  "HideFileExt"                /t REG_DWORD    /d 0x0 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"      ) /f  /v  "ShowSuperHidden"            /t REG_DWORD    /d 0x0 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"      ) /f  /v  "StartButtonBalloonTip"      /t REG_DWORD    /d 0x0 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"      ) /f  /v  "Start_ShowRun"              /t REG_DWORD    /d 0x1 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState"  ) /f  /v  "FullPathAddress"            /t REG_DWORD    /d 0x1 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Microsoft\Windows\CurrentVersion\Explorer\tips"          ) /f  /v  "Show"                       /t REG_DWORD    /d 0x0 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Microsoft\Windows\CurrentVersion\InternetSettings\Cache" ) /f  /v  "Persistent"                 /t REG_DWORD    /d 0x0 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"      ) /f  /v  "ForceStartMenuLogOff"       /t REG_DWORD    /d 0x1 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"      ) /f  /v  "HideSCAHealth"              /t REG_DWORD    /d 0x1 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"      ) /f  /v  "NoRecycleFiles"             /t REG_DWORD    /d 0x1 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"      ) /f  /v  "NoWelcomeScreen"            /t REG_DWORD    /d 0x1 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Microsoft\Windows\CurrentVersion\Policies\System"        ) /f  /v  "Wallpaper"                  /t REG_SZ       /d "." | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Policies\Microsoft\Internet Explorer\Main"               ) /f  /v  "DisableFirstRunCustomize"   /t REG_DWORD    /d 0x1 | Write-Verbose

      Write-Verbose "  Setting screensaver parameters ..."
      & reg.exe add ( Join-Path $RegBasePath "Software\Policies\Microsoft\Windows\Control Panel\Desktop" ) /f  /v "ScreenSaveActive"    /t REG_SZ    /d 0   | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Policies\Microsoft\Windows\Control Panel\Desktop" ) /f  /v "ScreenSaverIsSecure" /t REG_SZ    /d 0   | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Policies\Microsoft\Windows\Control Panel\Desktop" ) /f  /v "ScreenSaveTimeOut"   /t REG_SZ    /d 0   | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Policies\Microsoft\Windows\Control Panel\Desktop" ) /f  /v "ScreenSaveTimeOut"   /t REG_SZ    /d 0   | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Policies\Microsoft\Windows NT\SystemRestore"      ) /f  /v "DisableSR"           /t REG_DWORD /d 0x1 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "Software\Policies\Microsoft\Windows\Sideshow"              ) /f  /v "Disabled"            /t REG_DWORD /d 0x1 | Write-Verbose

      Write-Verbose "  Setting crashcontrol parameters ..."
      & reg.exe add ( Join-Path $RegBasePath "SYSTEM\CurrentControlSet\Control\CrashControl"                      ) /f  /v "CrashDumpEnabled"          /t REG_DWORD    /d 0x0 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "SYSTEM\CurrentControlSet\Control\CrashControl"                      ) /f  /v "LogEvent"                  /t REG_DWORD    /d 0x0 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "SYSTEM\CurrentControlSet\Control\CrashControl"                      ) /f  /v "SendAlert"                 /t REG_DWORD    /d 0x0 | Write-Verbose
      & reg.exe add ( Join-Path $RegBasePath "SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" ) /f  /v "ClearPageFileAtShutdown"   /t REG_DWORD    /d 0x0 | Write-Verbose

      # 'Disable Superfetch & Prefetch for SSD in Windows 8 / 7' http://www.thewindowsclub.com/disable-superfetch-prefetch-ssd
      & reg.exe add ( Join-Path $RegBasePath "SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" ) /f /v "EnableSuperfetch" /t REG_DWORD /d 0x1 | Write-Verbose

      # 'The Windows Disk timeout value: Less is better - Windows Storage Team - Site Home - MSDN Blogs'
      # http://blogs.msdn.com/b/san/archive/2011/09/01/the-windows-disk-timeout-value-understanding-why-this-should-be-set-to-a-small-value.aspx
      & reg.exe add ( Join-Path $RegBasePath "SYSTEM\CurrentControlSet\Services\Disk"                             )   /f  /v  "TimeOutValue"              /t REG_DWORD    /d 0xA | Write-Verbose
    }

    & reg.exe unload  $HKUDefaultUserTemp | Write-Verbose
  }
}


function Disable-NonEssentialServices {         #M:VDIOptimizations
  [CmdletBinding()]
  Param()
  $vp = $VerbosePreference
  Write-Verbose "Disabling Non-Essential Windows Services"
  Set-Service "helpsvc"         -StartupType "Manual"     -ea 0 -Verbose:$vp # Help_and_Support
  Set-Service "defragsvc"       -StartupType "Disabled"   -ea 0 -Verbose:$vp # Optimize_drives
  Set-Service "ERSvc"           -StartupType "Manual"     -ea 0 -Verbose:$vp # Error_Reporting  Service
  Set-Service "WerSvc"          -StartupType "Manual"     -ea 0 -Verbose:$vp # Windows_Error_Reporting_Service
  Set-Service "WinDefend"       -StartupType "Disabled"   -ea 0 -Verbose:$vp # Windows_Defender_Service
  Set-Service "wscsvc"          -StartupType "Manual"     -ea 0 -Verbose:$vp # Security_Center
  Set-Service "WSearch"         -StartupType "Disabled"   -ea 0 -Verbose:$vp # Windows_Search
  Set-Service "wuauserv"        -StartupType "Disabled"   -ea 0 -Verbose:$vp # Automatic_Updates
  Set-Service "WZCSVC"          -StartupType "Manual"     -ea 0 -Verbose:$vp # Wireless Zero_Configuration
  Set-Service "TapiSrv"         -StartupType "Manual"     -ea 0 -Verbose:$vp # Telephony
  Set-Service "BITS"            -StartupType "Manual"     -ea 0 -Verbose:$vp # Background_Intelligent_Transfer_Services
  Set-Service "RemoteRegistry"  -StartupType "Manual"     -ea 0 -Verbose:$vp # Remote_Registry
  # SuperFetch ???
}


function Disable-NonEssentialStartupTasks {     #M:VDIOptimizations
  [CmdletBinding()]
  Param()
  Write-Verbose "Disabling Non-Essential Startup Tasks"
  Uninstall-GlobalLogonScript "Windows Defender"      -Verbose:$VerbosePreference -ea 0 # Vista
  Uninstall-GlobalLogonScript "BrowserChoice"         -Verbose:$VerbosePreference -ea 0 # Win8, XP
  Uninstall-UserLogonScript   "CTFMON.EXE"            -Verbose:$VerbosePreference -ea 0 # XP
  Uninstall-UserLogonScript   "Sidebar"               -Verbose:$VerbosePreference -ea 0 # Vista Sidebar
  Uninstall-UserLogonScript   "WindowsWelcomeCenter"  -Verbose:$VerbosePreference -ea 0 # Vista
}


function Disable-NonEssentialScheduledTasks {   #M:TaskUtils
  [CmdletBinding()]
  Param()
  Write-Verbose "Disabling Scheduled Tasks"
  Disable-ScheduledTask "\Microsoft\Windows\ApplicationData\CleanupTemporaryState"                        -Verbose:$VerbosePreference -ea 0 # Cleans up each package's unused temporary files.
  Disable-ScheduledTask "\Microsoft\Windows\Application Experience\StartupAppTask"                        -Verbose:$VerbosePreference -ea 0 # Scans startup entries and rasies notification to the user if there are too many startup entries.
  Disable-ScheduledTask "\Microsoft\Windows\Autochk\Proxy"                                                -Verbose:$VerbosePreference -ea 0 # This task collects and uploads autochk SQM data if opted-in to the Microsoft Customer.
  Disable-ScheduledTask "\Microsoft\Windows\Chkdsk\ProactiveScan"                                         -Verbose:$VerbosePreference -ea 0 # NTFS Volume Health Scan
  Disable-ScheduledTask "\Microsoft\Windows\Data Integrity Scan\Data Integrity Scan"                      -Verbose:$VerbosePreference -ea 0 # Scans fault-tolerant volumes for fast crash recovery
  Disable-ScheduledTask "\Microsoft\Windows Defender\MPIdleBackup"                                        -Verbose:$VerbosePreference -ea 0 # Windows Defender Scheduled Scan
  Disable-ScheduledTask "\Microsoft\Windows Defender\MP Scheduled Scan"                                   -Verbose:$VerbosePreference -ea 0 # Windows Defender Scheduled Scan
  Disable-ScheduledTask "\Microsoft\Windows\Defrag\ScheduledDefrag"                                       -Verbose:$VerbosePreference -ea 0 # This task defragments the computers hard disk drives.
  Disable-ScheduledTask "\Microsoft\Windows\Diagnosis\Scheduled"                                          -Verbose:$VerbosePreference -ea 0 # The Windows Scheduled Maintenance Task performs periodic maintenance of the computer system by fixing problems automatically or reporting them through the Action Center.
  Disable-ScheduledTask "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" -Verbose:$VerbosePreference -ea 0 # The Windows Disk Diagnostic reports general disk and system information to Microsoft for users participating in the Customer Experience Program.
  Disable-ScheduledTask "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver"      -Verbose:$VerbosePreference -ea 0 # The Microsoft-Windows-DiskDiagnosticResolver warns users about faults reported by hard disks that support the Self Monitoring and Reporting Technology (S.M.A.R.T.) standard. This task is triggered automatically by the Diagnostic Policy Service when a S.
  Disable-ScheduledTask "\Microsoft\Windows\FileHistory\File History (maintenance mode)"                  -Verbose:$VerbosePreference -ea 0 # Protects user files from accidental loss by copying them to a backup location when the system is unattended
  Disable-ScheduledTask "\Microsoft\Windows\Maintenance\WinSAT"                                           -Verbose:$VerbosePreference -ea 0 # System Assessment Tool Scheduled Scan
  Disable-ScheduledTask "\Microsoft\Windows\Media Center\ActivateWindowsSearch"                           -Verbose:$VerbosePreference -ea 0 # Privileged Media Center Search Reindexing job
  Disable-ScheduledTask "\Microsoft\Windows\Media Center\mcupdate"                                        -Verbose:$VerbosePreference -ea 0 # Check for Media Center updates.
  Disable-ScheduledTask "\Microsoft\Windows\MemoryDiagnostic\CorruptionDetector"                          -Verbose:$VerbosePreference -ea 0 # Task for launching the Memory Diagnostic
  Disable-ScheduledTask "\Microsoft\Windows\MemoryDiagnostic\DecompressionFailureDetector"                -Verbose:$VerbosePreference -ea 0 # Task for launching the Memory Diagnostic
  Disable-ScheduledTask "\Microsoft\Windows\MUI\LPRemove"                                                 -Verbose:$VerbosePreference -ea 0 # Launch language cleanup tool
  Disable-ScheduledTask "\Microsoft\Windows\.NET Framework\.Net Framework NGEN v4.0.30319 Critical"       -Verbose:$VerbosePreference -ea 0 # NGEN Service
  Disable-ScheduledTask "\Microsoft\Windows\.NET Framework\.Net Framework NGEN v4.0.30319"                -Verbose:$VerbosePreference -ea 0 # NGEN Service
  Disable-ScheduledTask "\Microsoft\Windows\Offline Files\Background Synchronization"                     -Verbose:$VerbosePreference -ea 0 # This task controls periodic background synchronization of Offline Files when the user is working in an offline mode.
  Disable-ScheduledTask "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"                   -Verbose:$VerbosePreference -ea 0 # This job analyzes the system looking for conditions that may cause high energy use.
  Disable-ScheduledTask "\Microsoft\Windows\Registry\RegIdleBackup"                                       -Verbose:$VerbosePreference -ea 0 # Registry Idle Backup Task
  Disable-ScheduledTask "\Microsoft\Windows\RemoteAssistance\RemoteAssistanceTask"                        -Verbose:$VerbosePreference -ea 0 # Checks group policy for changes relevant to Remote Assistance
  Disable-ScheduledTask "\Microsoft\Windows\Servicing\StartComponentCleanup"                              -Verbose:$VerbosePreference -ea 0 # N/A
  Disable-ScheduledTask "\Microsoft\Windows\SettingSync\BackgroundUploadTask"                             -Verbose:$VerbosePreference -ea 0 # N/A
  Disable-ScheduledTask "\Microsoft\Windows\Shell\CrawlStartPages"                                        -Verbose:$VerbosePreference -ea 0 # Index all crawl type start addresses.
  Disable-ScheduledTask "\Microsoft\Windows\SideShow\AutoWake"                                            -Verbose:$VerbosePreference -ea 0 # This task automatically wakes the computer and then puts it to sleep when automatic wake is turned on for a Windows SideShow-compatible device.
  Disable-ScheduledTask "\Microsoft\Windows\SideShow\GadgetManager"                                       -Verbose:$VerbosePreference -ea 0 # This task manages and synchronizes metadata for the installed gadget s on a Windows SideShow-compatible device.
  Disable-ScheduledTask "\Microsoft\Windows\SideShow\SessionAgent"                                        -Verbose:$VerbosePreference -ea 0 # This task manages the session behavior when multiple user accounts exist on a Windows SideShow-compatible device.
  Disable-ScheduledTask "\Microsoft\Windows\SystemRestore\SR"                                             -Verbose:$VerbosePreference -ea 0 # This task creates regular system protection points.
  Disable-ScheduledTask "\Microsoft\Windows\WindowsBackup\ConfigNotification"                             -Verbose:$VerbosePreference -ea 0 # This scheduled task notifies the user that Windows Backup has not been configured.
  Disable-ScheduledTask "\Microsoft\Windows\WindowsColorSystem\Calibration Loader"                        -Verbose:$VerbosePreference -ea 0 # This task applies color calibration settings.
  Disable-ScheduledTask "\Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance"          -Verbose:$VerbosePreference -ea 0 # Periodic maintenance task.
  Disable-ScheduledTask "\Microsoft\Windows\Windows Defender\Windows Defender Cleanup"                    -Verbose:$VerbosePreference -ea 0 # Periodic cleanup task.
  Disable-ScheduledTask "\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan"             -Verbose:$VerbosePreference -ea 0 # Periodic scan task.
  Disable-ScheduledTask "\Microsoft\Windows\Windows Defender\Windows Defender Verification"               -Verbose:$VerbosePreference -ea 0 # Periodic verification task.
  Disable-ScheduledTask "\Microsoft\Windows\Windows Error Reporting\QueueReporting"                       -Verbose:$VerbosePreference -ea 0 # Windows Error Reporting task to process queued reports.
  Disable-ScheduledTask "\Microsoft\Windows\Windows Media Sharing\UpdateLibrary"                          -Verbose:$VerbosePreference -ea 0 # This task updates the cached list of folders and the security permissions on any new files in a users shared media library.
  Disable-ScheduledTask "\Microsoft\Windows\WindowsUpdate\AUScheduledInstall"                             -Verbose:$VerbosePreference -ea 0 # Initiates scheduled install of updates on the machine.
  Disable-ScheduledTask "\Microsoft\Windows\WindowsUpdate\AUSessionConnect"                               -Verbose:$VerbosePreference -ea 0 # This task is used to display notifications to users.
  Disable-ScheduledTask "\Microsoft\Windows\WindowsUpdate\Scheduled Start"                                -Verbose:$VerbosePreference -ea 0 # This task is used to start the Windows Update service when needed to perform scheduled operations such as scans.
  Disable-ScheduledTask "\Microsoft\Windows\WS\Sync Licenses"                                             -Verbose:$VerbosePreference -ea 0 # Store License Sync
  Disable-ScheduledTask "\Microsoft\Windows\WS\WSRefreshBannedAppsListTask"                               -Verbose:$VerbosePreference -ea 0 # Store Refresh Banned App List Task
  Disable-ScheduledTask "\Microsoft\Windows\WS\WSTask"                                                    -Verbose:$VerbosePreference -ea 0 # Windows Store Maintenance Task
  Disable-ScheduledTask "\WPD\SqmUpload_S-1-5-21-2937843477-3889217746-2470408325-1001"                   -Verbose:$VerbosePreference -ea 0 # This task uploads Customer Experience Improvement Program (CEIP) data for Portable Devices
  Disable-ScheduledTask "\WPD\SqmUpload_S-1-5-21-2937843477-3889217746-2470408325-500"                    -Verbose:$VerbosePreference -ea 0 # This task uploads Customer Experience Improvement Program (CEIP) data for Portable Devices
}


function Disable-WindowsSidebar {               #M:VDIOptimizations
  [CmdletBinding()]
  Param()

  $Fixit50906 = "http://go.microsoft.com/?linkid=9813057"
  $Fixit50906msi = Join-Path $Env:TEMP "MicrosoftFixit50906.msi"

  $WebClient = New-Object System.Net.WebClient
  try {
    $WebClient.Downloadfile( $Fixit50906, $Fixit50906msi )
  } catch [Exception] {
    Write-Error "Unable to download MicrosoftFixit50906.msi"
  }

  $args = ( '/i', $Fixit50906msi, '/quiet', '/passive', '/qn', '/norestart', '/l', '*', '/log', "$Env:TEMP\fixit50906.msi.log" )
  Write-Verbose "  msiexec.exe $args"
  $process = Start-Process -FilePath $(Join-Path "$Env:WINDIR\System32" msiexec.exe) -ArgumentList $args -wait -PassThru

  if (-not $process ) {
    Write-Error "Error invoking msiexec $args"
  } else {
    $process | Wait-Process
  }
  Write-Verbose "  ExitCode : $($process.ExitCode)"
  return $process.ExitCode
}


function Set-PowerSchemeOptimizations {
  [CmdletBinding()]
  Param()
  Write-Verbose "Setting PowerScheme"
  if ( (gwmi Win32_OperatingSystem).Version -lt 6) { # xp
    & powercfg.exe -setactive "Always On"
    & powercfg.exe -query
  }
  else {
    & powercfg.exe -setactive scheme_min          # always on
    & powercfg.exe -getactivescheme
    & powercfg.exe -h off                         # disable hibernation
    & powercfg.exe -change -monitor-timeout-ac 0  # disable display blanking
    & powercfg.exe -change -standby-timeout-ac 0  # disable standby
    & powercfg.exe -change -disk-timeout-ac    0  # disable turning off disks
  }
  Write-Host ''
}


# vim:sw=2:ts=2:et:foldexpr=getline(v\:lnum)=~'^\s*$'&&getline(v\:lnum-1)=~'^\s*$'&&getline(v\:lnum+1)=~'\S'?'<1'\:1:fdm=expr:filetype=ps1:ff=dos:fenc=ASCII

