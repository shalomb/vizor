# Powershell

# This file is not to be meant to run directly.

[CmdletBinding()]
Param()

Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0

$ErrorActionPreference          = 'STOP'
$PSModuleAutoLoadingPreference  = 'STOP'

# Import all modules required by tasks defined below
Import-Module Microsoft.PowerShell.Host -ea 0 # Seems to fail import on PSv2
Import-Module CDROM
Import-Module GroupPolicy
Import-Module Locale
Import-Module MSRT
Import-Module OSRegion
Import-Module RegistryUtils
Import-Module RDP
Import-Module Robocopy
Import-Module SystemUtils
Import-Module TaskUtils
Import-Module VDIOptimizations
Import-Module WindowsActivation
Import-Module WindowsDefender
Import-Module WindowsUpdate
Import-Module WinMgmt
Import-Module ZipUtils

# Tasks Outstanding
#  Enable Pagefile on first startup
#  Language Packs
#  Source Parameters from config file
#  Windows8and2012VDIBaseline.vbs
#  Review

# Define the environment for the run
$Env:OLBASE       = "$Env:SystemDrive\ProgramData\OneLab"
$Env:OLCONF       = Join-Path $Env:OLBASE "conf"
$Env:OLBIN        = Join-Path $Env:OLBASE "bin"
$Env:OLLOG        = Join-Path $Env:OLBASE "log"
$Env:OLIP         = Join-Path $Env:OLLOG  "ImagePrep"

$Env:KMS_SERVER   = 'camesvwkms01.eng.citrite.net'
$Env:KMS_PORT     = '1688'
$Env:NTP_SERVERS  = 'eng.citrite.net,citrite.net,pool.ntp.org,time.windows.com,time.nis.gov'
$Env:WSUS_URL     = 'http://cam-eiwsus.eng.citrite.net:8530'

if ( (Test-Path "bin\SysInternals") ) { $Env:PATH += "$($PWD.ProviderPath)\bin\SysInternals;" }
$Env:PATH += "$Env:OLBIN;$Env:IPBaseDir\bin\SysInternals"

# Stage 0
@(
  @{ name    =   'create_onelab_support_directory_hierarchy';
      script = {
        $Env:OLBASE,$Env:OLCONF,$Env:OLBIN,$Env:OLLOG,$Env:OLIP | %{
          mkdir -Force -Verbose:$VerbosePreference $_ | Out-Null
        }
      };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'set_ntp_servers';
      script = { Set-NTPServers $Env:NTP_SERVERS -Verbose };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'sync_ntp_time_stage_0';
      script = { Sync-W32Time };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'enable_crash_control_crash_dump_full';
      script = { Enable-CrashControlCrashDump -Value 1 -Verbose:$VerbosePreference };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'enable_crash_control_nmi_crash_dump';
      script = { Enable-NMICrashDump -Verbose:$VerbosePreference };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'enable_crash_control_autoreboot';
      script = { Enable-CrashControlAutoReboot -Verbose:$VerbosePreference };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'enable_crash_control_dump_file_overwrite';
      script = { Enable-CrashControlDumpFileOverWrite -Verbose:$VerbosePreference };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'enable_crash_control_send_alert';
      script = { Enable-CrashControlSendAlert -Verbose:$VerbosePreference };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'enable_crash_control_log_system_event';
      script = { Enable-CrashControlLogEvent -Verbose:$VerbosePreference };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'enable_crash_control_always_keep_memory_dump';
      script = { Enable-CrashControlAlwaysKeepMemoryDump -Verbose:$VerbosePreference };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'disable_first_logon_animations';
      script = { Disable-FirstLogonAnimations };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'disable_server_manager';
      script = { Disable-ServerManager -Verbose:$VerbosePreference };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'uninstall_msmsgs_startup_commands';
      pre    = { if (-not((Get-OSVersion).CurrentVersion -imatch '5.1')){ throw 'Not on Windows XP/2003.' } };
      script = { try { Get-StartupCommand | ?{ $_.Caption -imatch 'msmsgs' } | Uninstall-StartupCommand -Verbose:$VerbosePreference } catch {} }; post   = { 1 }; }
  @{ name    =   'uninstall_ctfmon_startup_commands';
      pre    = { if (-not((Get-OSVersion).CurrentVersion -imatch '5.1')){ throw 'Not on Windows XP/2003.' } };
      script = { try { Get-StartupCommand | ?{ $_.Caption -imatch 'ctfmon.exe' } | Uninstall-StartupCommand -Verbose:$VerbosePreference }catch{}}; post   = { 1 }; }
  @{ name    =   'uninstall_welcomecenter_startup_commands';
      pre    = { $os = gwmi win32_operatingsystem; if (-not($os.version -imatch '^(?:5\.0|6\.0)')){} };
      script = { try { Get-StartupCommand | ?{ $_.Caption -imatch 'welcomecenter' } | Uninstall-StartupCommand -Verbose:$VerbosePreference }catch{}}; post   = { 1 }; }
  @{ name    =   'uninstall_sidebar_startup_commands';
      pre    = { $os = gwmi win32_operatingsystem; if (-not($os.version -imatch '^6\.[01]')){ Write-Warning 'Not on Windows Vista/7.' } };
      script = { try { Get-StartupCommand | ?{ $_.Caption -imatch 'sidebar' } | Uninstall-StartupCommand -Verbose:$VerbosePreference } catch{} }; post   = { 1 }; }
  @{ name    =   'uninstall_windows_defender_startup_commands';
      pre    = { 1 };
      script = { try { Get-StartupCommand | ?{ $_.Caption -imatch 'windows defender' } | Uninstall-StartupCommand -Verbose:$VerbosePreference } catch{} }; post   = { 1 }; }
  @{ name    =   'disable_windows_sidebar';
      script = { Disable-WindowsSidebar -Verbose:$VerbosePreference };
      pre    = { $os = gwmi win32_operatingsystem; if (-not($os.version -imatch '^6\.0')){ throw 'Not on Windows Vista.' } }; post   = { 1 }; }
  @{ name    =   'disable_screensaver';
      script = { Disable-ScreenSaver -Verbose:$VerbosePreference };
      pre    = { 1 }; post   = { 1 }; }
  # @{ name    =   'create_local_administrator';
  #     script = { New-LocalAdministrativeUser -Username "Administrator" -Password "***REMOVED***" -Verbose:$VerbosePreference -ea 0 };
  #     pre    = { if ( (Get-CurrentDomain).PartOfDomain ) { Throw "Computer is a domain member." } }; post   = { 1 }; }
  # # Backup administrator
  # @{ name    =   'create_local_administrator_citrix';
  #     script = { New-LocalAdministrativeUser -Username "citrix" -Password "***REMOVED***" -Verbose:$VerbosePreference -ea 0 };
  #     pre    = { if ( (Get-CurrentDomain).PartOfDomain ) { Throw "Computer is a domain member." } }; post   = { 1 }; }
  @{ name    =   'initialize_sysinternals_tools';
      script = { SystemUtils\Initialize-SysInternals };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'disable_system_restore';
      script = { Disable-SystemResoreOnLocalDrives -ea 0 };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'set_cscript_as_wsh_host';
      script = { Set-WSHScriptHost "CScript" };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'enable_show_desktop_on_logon';
      script = { Enable-ShowDesktopOnLogon };
      pre    = { 1 }; post   = { 1 }; }
#  @{ name    =   'enable_windows_updates';
#      script = { Enable-WindowsUpdates };
#      pre    = { 1 }; post   = { 1 }; }
#  @{ name    =   'install_dotnet35_on_2008r2';
#      script = { if (-not(Test-Path "$Env:WINDIR\Microsoft.Net\Framework*\v3*")) {
#                    Import-Module ServerManager -Verbose:$VerbosePreference;
#                    Add-WindowsFeature as-net-framework -Verbose:$VerbosePreference
#                  }
#      };
#      pre    = { $os = gwmi win32_operatingsystem; if (-not($os.version -imatch '^6.1.7601')){ throw 'Not on Windows 2008 R2.' } }; post   = { 1 }; }
#  @{ name    =   'install_windows_updates';
#      script = { Search-WindowsUpdate -ImportantOnly -Verbose:$VerbosePreference | Install-WindowsUpdate -Verbose:$VerbosePreference };
#      pre    = { 1 }; post   = { 1 }; }
#  @{ name    =   'invoke_windows_defender_signature_update';
#      script = { Invoke-WindowsDefenderUpdate -Verbose:$VerbosePreference };
#      pre    = { $os = gwmi win32_operatingsystem; if ($os.version -imatch '^(?:6\.[1-9])'){ throw 'On Windows 8.1/2012R2.' } }; post   = { 1 }; }
#  @{ name    =   'update_powershell_help';
#      script = { Update-Help -Verbose:$VerbosePreference };
#      pre    = { $psver=$PSVersionTable.PSversion; if (-not($psver -ge 3.0)){ throw 'Not on PowerShell >= 3.0.' } }; post   = { 1 }; }
#  @{ name    =   'disable_windows_updates';
#      script = { Disable-WindowsUpdates };
#      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'disable_screen_savers';
      script = { Disable-ScreenSaver };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'disable_auto_reboot_on_system_failure';
      script = { Disable-AutoRebootOnSystemFailure };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'set_user_preferences';
      script = { Set-UserPreferences -Verbose:$VerbosePreference };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'disable_device_autorun';
      script = { Disable-AutoRun };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'set_w32tm_service_autostart';
      script = {  Get-Service -Name W32Time | Set-Service -StartupType Automatic -Verbose:$VerbosePreference };
      pre    = { 1 }; post   = { 1 }; }

  # Configure Service Startup Type

  # Application Layer Gateway Service
  @{ name    =  'set_service__alg';
      script = { Set-Service 'ALG' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Bitlocker Drive Encryption Service
  @{ name    =  'set_service__bdesvc';
      script = { Set-Service 'BDESVC' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # BITS - Background Intelligent Transfer Services
  @{ name    =  'set_service__bits_background_intelligent_transfer_services_to_startuptype_manual';
      script = { Set-Service 'BITS' -StartupType 'Manual' -ea 0 -verb:$VerbosePreference;  };
      pre    = { 1 }; post   = { 1 }; }
  # Background Intelligent Transfer Service
  @{ name    =  'set_service__bits';
      script = { Set-Service 'BITS' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Computer Browser Service
  @{ name    =  'set_service__browser';
      script = { Set-Service 'Browser' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Offline Files
  @{ name    =  'set_service__cscservice';
      script = { Set-Service 'CscService' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # DefragSvc - Optimize Drives
  @{ name    =  'set_service__defragsvc_optimize_drives_to_startuptype_disabled';
      script = { Set-Service 'defragsvc' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference;  };
      pre    = { 1 }; post   = { 1 }; }
  # Device Association Service
  @{ name    =  'set_service__deviceassociationservice';
      script = { Set-Service 'DeviceAssociationService' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Diagnostic Policy Services
  @{ name    =  'set_service__dps';
      script = { Set-Service 'DPS' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Device Setup Manager Service
  @{ name    =  'set_service__dsmsvc';
      script = { Set-Service 'DsmSvc' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Encrypting File System Service
  @{ name    =  'set_service__efs';
      script = { Set-Service 'EFS' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # ErSvc - Error Reporting
  @{ name    =  'set_service__ersvc_error_reporting_to_startuptype_manual';
      script = { Set-Service 'ERSvc' -StartupType 'Manual' -ea 0 -verb:$VerbosePreference;  };
      pre    = { 1 }; post   = { 1 }; }
  # Fax Service
  @{ name    =  'set_service__fax';
      script = { Set-Service 'Fax' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Fax - Fax
  @{ name    =  'set_service__fax_to_startuptype_disabled';
      script = { Set-Service 'Fax' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference;  };
      pre    = { 1 }; post   = { 1 }; }
  # Function Discovery Resource Publication Service
  @{ name    =  'set_service__fdrespub';
      script = { Set-Service 'FDResPub' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # HelpSvc - Help and Support Service
  @{ name    =  'set_service__helpsvc_help_and_support_to_startuptype_manual';
      script = { Set-Service 'helpsvc' -StartupType 'Manual' -ea 0 -verb:$VerbosePreference;  };
      pre    = { 1 }; post   = { 1 }; }
  # HomeGroup Listener Service
  @{ name    =  'set_service__homegrouplistener';
      script = { Set-Service 'HomeGroupListener' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # HomeGroup Provider Service
  @{ name    =  'set_service__homegroupprovider';
      script = { Set-Service 'HomeGroupProvider' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Microsoft iSCSI Initiator Service
  @{ name    =  'set_service__msiscsi';
      script = { Set-Service 'msiscsi' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Set Network List Service to Auto
  @{ name    =  'set_service__netprofm';
      script = { Set-Service 'netprofm' -StartupType 'Automatic' };
      pre    = { 1 }; post   = { 1 }; }
  # BranchCache Service
  @{ name    =  'set_service__peerdistsvc';
      script = { Set-Service 'PeerDistSvc' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # RemoteRegistry - Remote Registry
  @{ name    =  'set_service__remoteregistry_remote_registry_to_startuptype_manual';
      script = { Set-Service 'RemoteRegistry' -StartupType 'Manual' -ea 0 -verb:$VerbosePreference;  };
      pre    = { 1 }; post   = { 1 }; }
  # Windows Backup Service
  @{ name    =  'set_service__sdrsvc';
      script = { Set-Service 'SDRSVC' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Sensor Monitoring Service
  @{ name    =  'set_service__sensrsvc';
      script = { Set-Service 'SensrSvc' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Shell Hardware Detection Service
  @{ name    =  'set_service__shellhwdetection';
      script = { Set-Service 'ShellHWDetection' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # SNMP Trap Service
  @{ name    =  'set_service__snmptrap';
      script = { Set-Service 'SNMPTRAP' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # SSDP Discovery Service
  @{ name    =  'set_service__ssdpsrv';
      script = { Set-Service 'SSDPSRV' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Secure Socket Tunneling Protocol Service
  @{ name    =  'set_service__sstpsvc';
      script = { Set-Service 'SstpSvc' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Microsoft Software Shadow Copy Provider Service
  @{ name    =  'set_service__swprv';
      script = { Set-Service 'swprv' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # SuperFetch
  @{ name    =  'set_service__sysmain';
      script = { Set-Service 'SysMain' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Telephony Service
  @{ name    =  'set_service__tapisrv';
      script = { Set-Service 'TapiSrv' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # TapiSrv - Telephony
  @{ name    =  'set_service__tapisrv_telephony_to_startuptype_manual';
      script = { Set-Service 'TapiSrv' -StartupType 'Manual' -ea 0 -verb:$VerbosePreference;  };
      pre    = { 1 }; post   = { 1 }; }
  # Themes Service
  @{ name    =  'set_service__themes';
      script = { Set-Service 'Themes' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Distributed Link Tracking Client Service
  @{ name    =  'set_service__trkwks';
      script = { Set-Service 'TrkWks' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # UPnP Device Host Service
  @{ name    =  'set_service__upnphost';
      script = { Set-Service 'upnphost' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Volume Shadow Copy Service
  @{ name    =  'set_service__vss';
      script = { Set-Service 'VSS' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Block Level Backup Engine Service
  @{ name    =  'set_service__wbengine';
      script = { Set-Service 'wbengine' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Windows Connect Now - Config Registrar Service
  @{ name    =  'set_service__wcncsvc';
      script = { Set-Service 'wcncsvc' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Windows Color System Service
  @{ name    =  'set_service__wcspluginservice';
      script = { Set-Service 'WcsPlugInService' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Diagnostic Policy Services
  @{ name    =  'set_service__wdiservicehost';
      script = { Set-Service 'WdiServiceHost' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Diagnostic Policy Services
  @{ name    =  'set_service__wdisystemhost';
      script = { Set-Service 'WdiSystemHost' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Windows Error Reporting Service
  @{ name    =  'set_service__wersvc';
      script = { Set-Service 'WerSvc' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # WerSvc - Error Reporting
  @{ name    =  'set_service__wersvc_windows_error_reporting_service_to_startuptype_manual';
      script = { Set-Service 'WerSvc' -StartupType 'Manual' -ea 0 -verb:$VerbosePreference;  };
      pre    = { 1 }; post   = { 1 }; }
  # WinDefend - Windows Defender
  @{ name    =  'set_service__windefend_windows_defender_service_to_startuptype_disabled';
      script = { Set-Service 'WinDefend' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference;  };
      pre    = { 1 }; post   = { 1 }; }
  # Windows Defender Service
  @{ name    =  'set_service__windefent';
      script = { Set-Service 'WinDefend' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # WLAN AutoConfig Service
  @{ name    =  'set_service__wlansvc';
      script = { Set-Service 'Wlansvc' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Windows Media Player Network Sharing Service
  @{ name    =  'set_service__wmpnetworksvc';
      script = { Set-Service 'WMPNetworkSvc' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Family Safety Service
  @{ name    =  'set_service__wpcsvc';
      script = { Set-Service 'WPCSvc' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # Security Center
  @{ name    =  'set_service__wscsvc';
      script = { Set-Service 'wscsvc' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # WscSvc - Security Center
  @{ name    =  'set_service__wscsvc_security_center_to_startuptype_manual';
      script = { Set-Service 'wscsvc' -StartupType 'Manual' -ea 0 -verb:$VerbosePreference;  };
      pre    = { 1 }; post   = { 1 }; }
  # Windows Search Service
  @{ name    =  'set_service__wsearch';
      script = { Set-Service 'WSearch' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # WSearch - Windows Search
  @{ name    =  'set_service__wsearch_windows_search_to_startuptype_disabled';
      script = { Set-Service 'WSearch' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference;  };
      pre    = { 1 }; post   = { 1 }; }
  # WuauServ - Automatic Updates
  @{ name    =  'set_service__wuauserv_automatic_updates_to_startuptype_disabled';
      script = { Set-Service 'wuauserv' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference;  };
      pre    = { 1 }; post   = { 1 }; }
  # WzcSvc - Wireless Autoconfiguration
  @{ name    =  'set_service__wzcsvc_wireless_to_startuptype_manual';
      script = { Set-Service 'WZCSVC' -StartupType 'Manual' -ea 0 -verb:$VerbosePreference;  };
      pre    = { 1 }; post   = { 1 }; }
  # Windows Updates
  @{ name    =  'set_service__wuauserv';
      script = { Set-Service 'wuauserv' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }
  # WWAN AutoConfig Service
  @{ name    =  'set_service__wwansvc';
      script = { Set-Service 'WwanSvc' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference; };
      pre    = { 1 }; post   = { 1 }; }

  # Scheduled Task Status

  # Application Information Telemetry
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Application_Experience_AitAgent';
      script = { Disable-ScheduledTask "microsoft\windows\Application Experience\AitAgent" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Cleans up each package's unused temporary files.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_ApplicationData_CleanupTemporaryState';
      script = { Disable-ScheduledTask "\Microsoft\Windows\ApplicationData\CleanupTemporaryState" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Program Telemetry for the Microsoft Customer Experience Program
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Application_Experience_ProgramDataUpdater';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Application Experience\ProgramDataUpdater" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Scans startup entries and rasies notification to the user if there are too many startup entries.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Application_Experience_StartupAppTask';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Application Experience\StartupAppTask" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # This task collects and uploads autochk SQM data if opted-in to the Microsoft Customer.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Autochk_Proxy';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Autochk\Proxy" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Cleanup Bluetooth Devices
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Bluetooth_UninstallDeviceTask';
      script = { Disable-ScheduledTask "microsoft\windows\Bluetooth\UninstallDeviceTask" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # NTFS Volume Health Scan
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Chkdsk_ProactiveScan';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Chkdsk\ProactiveScan" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Telemtry for the Customer Experience Program
  @{ name    = 'disable_scheduled_task__Microsoft_Windows_Customer Experience Improvement Program_BthSQM';
      script = { Disable-ScheduledTask '\Microsoft\Windows\Customer Experience Improvement Program\BthSQM' -ea 0 };
         pre = { 1 }; post = { 1 }; };
  @{ name    = 'disable_scheduled_task__Microsoft_Windows_Customer Experience Improvement Program_Consolidator';
      script = { Disable-ScheduledTask '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator' -ea 0 };
         pre = { 1 }; post = { 1 }; };
  @{ name    = 'disable_scheduled_task__Microsoft_Windows_Customer Experience Improvement Program_KernelCeipTask';
      script = { Disable-ScheduledTask '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask' -ea 0 };
         pre = { 1 }; post = { 1 }; };
  @{ name    = 'disable_scheduled_task__Microsoft_Windows_Customer Experience Improvement Program_Uploader';
      script = { Disable-ScheduledTask '\Microsoft\Windows\Customer Experience Improvement Program\Uploader' -ea 0 };
         pre = { 1 }; post = { 1 }; };
  @{ name    = 'disable_scheduled_task__Microsoft_Windows_Customer Experience Improvement Program_UsbCeip';
      script = { Disable-ScheduledTask '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip' -ea 0 };
         pre = { 1 }; post = { 1 }; };
  # Scans fault-tolerant volumes for fast crash recovery
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Data_Integrity_Scan_Data_Integrity_Scan';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Data Integrity Scan\Data Integrity Scan" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  @{ name    = 'disable_scheduled_task__Microsoft_Windows_Diagnosis_Scheduled';
       script = { Disable-ScheduledTask '\Microsoft\Windows\Diagnosis\Scheduled' -ea 0 };
           pre = { 1 }; post = { 1 }; };
  @{ name    = 'disable_scheduled_task__Microsoft_Windows_DiskDiagnostic_Microsoft-Windows-DiskDiagnosticDataCollector';
      script = { Disable-ScheduledTask '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector' -ea 0 };
         pre = { 1 }; post = { 1 }; };
  # Windows Defender Scheduled Scan
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Defender_MPIdleBackup';
      script = { Disable-ScheduledTask "\Microsoft\Windows Defender\MPIdleBackup" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Windows Defender Scheduled Scan
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Defender_MP_Scheduled_Scan';
      script = { Disable-ScheduledTask "\Microsoft\Windows Defender\MP Scheduled Scan" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # This task defragments the computers hard disk drives.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Defrag_ScheduledDefrag';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Defrag\ScheduledDefrag" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # The Windows Scheduled Maintenance Task performs periodic maintenance of the computer system by fixing problems automatically or reporting them through the Action Center.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Diagnosis_Scheduled';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Diagnosis\Scheduled" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # The Windows Disk Diagnostic reports general disk and system information to Microsoft for users participating in the Customer Experience Program.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_DiskDiagnostic_Microsoft-Windows-DiskDiagnosticDataCollector';
      script = { Disable-ScheduledTask "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # The Microsoft-Windows-DiskDiagnosticResolver warns users about faults reported by hard disks that support the Self Monitoring and Reporting Technology (S.M.A.R.T.) standard. This task is triggered automatically by the Diagnostic Policy Service when a S.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_DiskDiagnostic_Microsoft-Windows-DiskDiagnosticResolver';
      script = { Disable-ScheduledTask "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Protects user files from accidental loss by copying them to a backup location when the system is unattended
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_FileHistory_File_History_maintenance_mode';
      script = { Disable-ScheduledTask "\Microsoft\Windows\FileHistory\File History (maintenance mode)" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # System Assessment Tool Scheduled Scan
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Maintenance_WinSAT';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Maintenance\WinSAT" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Privileged Media Center Search Reindexing job
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Media_Center_ActivateWindowsSearch';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Media Center\ActivateWindowsSearch" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Check for Media Center updates.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Media_Center_mcupdate';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Media Center\mcupdate" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Task for launching the Memory Diagnostic
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_MemoryDiagnostic_CorruptionDetector';
      script = { Disable-ScheduledTask "\Microsoft\Windows\MemoryDiagnostic\CorruptionDetector" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Task for launching the Memory Diagnostic
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_MemoryDiagnostic_DecompressionFailureDetector';
      script = { Disable-ScheduledTask "\Microsoft\Windows\MemoryDiagnostic\DecompressionFailureDetector" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  @{ name    = 'disable_scheduled_task__Microsoft_Windows_MobilePC_HotStart';
      script = { Disable-ScheduledTask '\Microsoft\Windows\MobilePC\HotStart' -ea 0 };
         pre = { 1 }; post = { 1 }; };
  # Launch language cleanup tool
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_MUI_LPRemove';
      script = { Disable-ScheduledTask "\Microsoft\Windows\MUI\LPRemove" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  @{ name    = 'disable_scheduled_task__Microsoft_Windows_Power Efficiency Diagnostic_AnalyzeSystem';
      script = { Disable-ScheduledTask '\Microsoft\Windows\Power Efficiency Diagnostic\AnalyzeSystem' -ea 0 };
         pre = { 1 }; post = { 1 }; };
  @{ name    = 'disable_scheduled_task__Microsoft_Windows_RAC_RacTask';
      script = { Disable-ScheduledTask '\Microsoft\Windows\RAC\RacTask' -ea 0 };
         pre = { 1 }; post = { 1 }; };
  @{ name    = 'disable_scheduled_task__Microsoft_Windows_Ras_MobilityManager';
      script = { Disable-ScheduledTask '\Microsoft\Windows\Ras\MobilityManager' -ea 0 };
         pre = { 1 }; post = { 1 }; };
  # NGEN Service
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_.NET_Framework_.Net_Framework_NGEN_v4.0.30319_Critical';
      script = { Disable-ScheduledTask "\Microsoft\Windows\.NET Framework\.Net Framework NGEN v4.0.30319 Critical" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_.NET_Framework_.Net_Framework_NGEN_v4.0.30319 64_Critical';
      script = { Disable-ScheduledTask "\Microsoft\Windows\.NET Framework\.Net Framework NGEN v4.0.30319 64 Critical" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # NGEN Service
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_.NET_Framework_.Net_Framework_NGEN_v4.0.30319';
      script = { Disable-ScheduledTask "\Microsoft\Windows\.NET Framework\.Net Framework NGEN v4.0.30319" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_.NET_Framework_.Net_Framework_NGEN_v4.0.30319 64';
      script = { Disable-ScheduledTask "\Microsoft\Windows\.NET Framework\.Net Framework NGEN v4.0.30319 64" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # This task controls periodic background synchronization of Offline Files when the user is working in an offline mode.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Offline_Files_Background_Synchronization';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Offline Files\Background Synchronization" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # This job analyzes the system looking for conditions that may cause high energy use.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Power_Efficiency_Diagnostics_AnalyzeSystem';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Registry Idle Backup Task
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Registry_RegIdleBackup';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Registry\RegIdleBackup" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Checks group policy for changes relevant to Remote Assistance
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_RemoteAssistance_RemoteAssistanceTask';
      script = { Disable-ScheduledTask "\Microsoft\Windows\RemoteAssistance\RemoteAssistanceTask" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # N/A
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Servicing_StartComponentCleanup';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Servicing\StartComponentCleanup" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # N/A
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_SettingSync_BackgroundUploadTask';
      script = { Disable-ScheduledTask "\Microsoft\Windows\SettingSync\BackgroundUploadTask" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Index all crawl type start addresses.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Shell_CrawlStartPages';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Shell\CrawlStartPages" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  @{ name    = 'disable_scheduled_task__Microsoft_Windows_Shell_FamilySafetyMonitor';
      script = { Disable-ScheduledTask '\Microsoft\Windows\Shell\FamilySafetyMonitor' -ea 0 };
         pre = { 1 }; post = { 1 }; };
  @{ name    = 'disable_scheduled_task__Microsoft_Windows_Shell_FamilySafetyRefresh';
      script = { Disable-ScheduledTask '\Microsoft\Windows\Shell\FamilySafetyRefresh' -ea 0 };
         pre = { 1 }; post = { 1 }; };
  # This task automatically wakes the computer and then puts it to sleep when automatic wake is turned on for a Windows SideShow-compatible device.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_SideShow_AutoWake';
      script = { Disable-ScheduledTask "\Microsoft\Windows\SideShow\AutoWake" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # This task manages and synchronizes metadata for the installed gadget s on a Windows SideShow-compatible device.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_SideShow_GadgetManager';
      script = { Disable-ScheduledTask "\Microsoft\Windows\SideShow\GadgetManager" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # This task manages the session behavior when multiple user accounts exist on a Windows SideShow-compatible device.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_SideShow_SessionAgent';
      script = { Disable-ScheduledTask "\Microsoft\Windows\SideShow\SessionAgent" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  @{ name    = 'disable_scheduled_task__Microsoft_Windows_SideShow_SystemDataProviders';
      script = { Disable-ScheduledTask '\Microsoft\Windows\SideShow\SystemDataProviders' -ea 0 };
         pre = { 1 }; post = { 1 }; };
  # This task creates regular system protection points.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_SystemRestore_SR';
      script = { Disable-ScheduledTask "\Microsoft\Windows\SystemRestore\SR" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  @{ name    = 'disable_scheduled_task__Microsoft_Windows_UPnP_UPnPHostConfig';
      script = { Disable-ScheduledTask '\Microsoft\Windows\UPnP\UPnPHostConfig' -ea 0 };
         pre = { 1 }; post = { 1 }; };
  @{ name    = 'disable_scheduled_task__Microsoft_Windows_WDI_ResolutionHost';
      script = { Disable-ScheduledTask '\Microsoft\Windows\WDI\ResolutionHost' -ea 0 };
         pre = { 1 }; post = { 1 }; };
  # This scheduled task notifies the user that Windows Backup has not been configured.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_WindowsBackup_ConfigNotification';
      script = { Disable-ScheduledTask "\Microsoft\Windows\WindowsBackup\ConfigNotification" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  @{ name    = 'disable_scheduled_task__Microsoft_Windows_Windows Filtering Platform_BfeOnServiceStartTypeChange';
      script = { Disable-ScheduledTask '\Microsoft\Windows\Windows Filtering Platform\BfeOnServiceStartTypeChange' -ea 0 };
         pre = { 1 }; post = { 1 }; };
  # This task applies color calibration settings.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_WindowsColorSystem_Calibration_Loader';
      script = { Disable-ScheduledTask "\Microsoft\Windows\WindowsColorSystem\Calibration Loader" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Periodic maintenance task.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Windows_Defender_Windows_Defender_Cache_Maintenance';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Periodic cleanup task.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Windows_Defender_Windows_Defender_Cleanup';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Windows Defender\Windows Defender Cleanup" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Periodic scan task.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Windows_Defender_Windows_Defender_Scheduled_Scan';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Periodic verification task.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Windows_Defender_Windows_Defender_Verification';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Windows Defender\Windows Defender Verification" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Windows Error Reporting task to process queued reports.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Windows_Error_Reporting_QueueReporting';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Windows Error Reporting\QueueReporting" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # This task updates the cached list of folders and the security permissions on any new files in a users shared media library.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_Windows_Media_Sharing_UpdateLibrary';
      script = { Disable-ScheduledTask "\Microsoft\Windows\Windows Media Sharing\UpdateLibrary" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Initiates scheduled install of updates on the machine.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_WindowsUpdate_AUScheduledInstall';
      script = { Disable-ScheduledTask "\Microsoft\Windows\WindowsUpdate\AUScheduledInstall" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # This task is used to display notifications to users.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_WindowsUpdate_AUSessionConnect';
      script = { Disable-ScheduledTask "\Microsoft\Windows\WindowsUpdate\AUSessionConnect" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # This task is used to start the Windows Update service when needed to perform scheduled operations such as scans.
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_WindowsUpdate_Scheduled_Start';
      script = { Disable-ScheduledTask "\Microsoft\Windows\WindowsUpdate\Scheduled Start" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Store License Sync
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_WS_Sync_Licenses';
      script = { Disable-ScheduledTask "\Microsoft\Windows\WS\Sync Licenses" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Store Refresh Banned App List Task
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_WS_WSRefreshBannedAppsListTask';
      script = { Disable-ScheduledTask "\Microsoft\Windows\WS\WSRefreshBannedAppsListTask" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # Windows Store Maintenance Task
  @{ name    =   'disable_scheduled_task__Microsoft_Windows_WS_WSTask';
      script = { Disable-ScheduledTask "\Microsoft\Windows\WS\WSTask" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # This task uploads Customer Experience Improvement Program (CEIP) data for Portable Devices
  @{ name    =   'disable_scheduled_task__WPD_SqmUpload_S-1-5-21-2937843477-3889217746-2470408325-1001';
      script = { Disable-ScheduledTask "\WPD\SqmUpload_S-1-5-21-2937843477-3889217746-2470408325-1001" -ea 0; };
         pre = { 1 }; post = { 1 }; }
  # This task uploads Customer Experience Improvement Program (CEIP) data for Portable Devices
  @{ name    =   'disable_scheduled_task__WPD_SqmUpload_S-1-5-21-2937843477-3889217746-2470408325-500';
      script = { Disable-ScheduledTask "\WPD\SqmUpload_S-1-5-21-2937843477-3889217746-2470408325-500" -ea 0; };
         pre = { 1 }; post = { 1 }; }

  # @{ name    =   'add_powershell_assemblies_to_ngen_queue';
  #     script = { Add-AssemblyToNgenQueue -CurrentDomainAssemblies -Verbose:$VerbosePreference };
  #     pre    = { 1 }; post   = { 1 }; }
  # @{ name    =   'start_ngen_queued_tasks';
  #     script = { Start-NgenQueuedTasks -Verbose:$VerbosePreference };
  #     pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'set_powersheme_disable_hibernation';
      script = {  try {
        $Local:ErrorActionPreference = "CONTINUE"
        powercfg.exe -h off
        powercfg.exe -change -hibernate-timeout-ac 0
        powercfg.exe -change -hibernate-timeout-dc 0
      } catch {} };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'set_powerscheme_high_performance';
      script = {  try {
        $Local:ErrorActionPreference = "CONTINUE"
        powercfg.exe -s           8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        powercfg.exe -setabsentia 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        powercfg -setacvalueindex 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c fea3413e-7e05-4911-9a71-700331f1c294 245d8541-3943-4422-b025-13a784f679b7 1
        powercfg -setdcvalueindex 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c fea3413e-7e05-4911-9a71-700331f1c294 245d8541-3943-4422-b025-13a784f679b7 1
      } catch {} };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'set_powerscheme_always_on';
      script = {  try {
        $Local:ErrorActionPreference = "CONTINUE"
        powercfg.exe -setactive scheme_min
        powercfg.exe -setactive "Always On"
      } catch {} };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'set_powersheme_prevent_display_blanking';
      script = {  try {
        $Local:ErrorActionPreference = "CONTINUE"
        powercfg.exe -change -monitor-timeout-ac 0
      } catch {} };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'set_powersheme_standby_timout';
      script = {  try {
        $Local:ErrorActionPreference = "CONTINUE"
        powercfg.exe -change -standby-timeout-ac 0
      } catch {} };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'set_powersheme_disk_timeout';
      script = {  try {
        $Local:ErrorActionPreference = "CONTINUE"
        powercfg.exe -change -disk-timeout-ac 0
        powercfg.exe -setacvalueindex 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0
        powercfg.exe -setdcvalueindex 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0
      } catch {} };
      pre    = { 1 }; post   = { 1 }; }
# @{ name    =   'disable_automatic_managed_pagefile';
#     script = { Disable-AutomaticManagedPagefile -Verbose:$VerbosePreference };
#     pre    = { $os = gwmi win32_operatingsystem; if ($os.version -imatch '^5\.1'){ throw 'On Windows XP/2003.' } };
#     post   = { 1 }; }
# @{ name    =   'enable_clear_pagefile_at_shutdown';
#     script = { Enable-ClearPagefileAtShutdown -Verbose:$VerbosePreference };
#     pre    = { 1 };
#     post   = { 1 }; }
# @{ name    =   'delete_pagefiles';
#     script = { Get-Pagefile | Remove-Pagefile -Verbose:$VerbosePreference };
#     pre    = { 1 };
#     post   = { 1 }; }
# @{ name    =   'set_timezone_gmt';
#     pre    = { (Gwmi Win32_TimeZone) -imatch '^GMT Standard Time$' };
#     script = { Get-TimeZone -TimeZoneName 'GMT Standard Time' | Set-TimeZone -Verbose:$VerbosePreference };
#     post   = { (Gwmi Win32_TimeZone) -imatch '^GMT Standard Time$' }; }
  @{ name    =   'uninstall_browserchoice_startup_command';
      pre    = { 1 };
      script = { Get-StartupCommand | ?{ $_.Caption -imatch 'BrowserChoice' } | Uninstall-StartupCommand -Verbose:$VerbosePreference }; post   = { 1 }; }
  @{ name    =   'sync_ntp_time_stage_2';
      script = { Sync-W32Time };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'show_w32tm_status';
      script = { Show-W32tmStatus -Status };
      pre    = { 1 }; post   = { 1 }; }
#  @{ name    =   'enable_windows_updates_2';
#      script = { Enable-WindowsUpdates };
#      pre    = { 1 }; post   = { 1 }; }
#  @{ name    =   'install_windows_updates_2';
#      script = { Search-WindowsUpdate -ImportantOnly -Verbose:$VerbosePreference | Install-WindowsUpdate -Verbose:$VerbosePreference };
#      pre    = { 1 }; post   = { 1 }; }
#  @{ name    =   'invoke_windows_defender_signature_update_2';
#      script = { Invoke-WindowsDefenderUpdate -Verbose:$VerbosePreference };
#      pre    = { $os = gwmi win32_operatingsystem; if ($os.version -imatch '^(?:6\.[1-9])'){ throw 'On Windows 8.1/2012R2.' } }; post   = { 1 }; }
#  @{ name    =   'disable_windows_updates_2';
#      script = { Disable-WindowsUpdates };
#      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'install_taskbar_shortcut_items';
      script = { @("powershell", "cmd", "taskmgr", "eventvwr", "mmc","psr") | %{
          if (gcm $_ -ea 0) { try { Install-DesktopShortcut -Command "$_" } catch {} }
        }
      };
      pre    = { 1; }; post   = { 1 }; }
  @{ name    =   'set_kms_server';
      script = { & slmgr.vbs -skms "${Env:KMS_SERVER}:${Env:KMS_PORT}" };
      pre    = { $os = gwmi win32_operatingsystem; if ($os.version -imatch '^5\.1'){ throw 'On Windows XP/2003.' } }; post   = { 1 }; }
  @{ name    =   'activate_windows';
      script = { Invoke-WindowsActivation };
      pre    = { 1 }; post   = { 1 }; }
#  @{ name    =   'start_ngen_queued_tasks_2';
#      script = { Start-NgenQueuedTasks -Verbose:$VerbosePreference };
#      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'invoke_winmgmt_repository_reset';
      script = { try { Invoke-WinMgmt -ResetRepository }catch{} };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'invoke_winmgmt_repository_verify';
      script = { try { Invoke-WinMgmt -VerifyRepository }catch{} };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'invoke_windows_defender_full_scan';
      script = { Invoke-WindowsDefenderScan -Full -Verbose:$VerbosePreference };
      pre    = { $os = gwmi win32_operatingsystem; if ($os.version -imatch '^(?:6\.[1-9])'){ throw 'On Windows 8.1/2012R2.' } }; post   = { 1 }; }
  @{ name    =   'collect_windows_defender_files';
      script = { Invoke-WindowsDefenderCommand -MPCmdRunArgs @('-GetFiles') -Verbose:$VerbosePreference };
      pre    = { $os = gwmi win32_operatingsystem; if ($os.version -imatch '^(?:6\.[1-9])'){ throw 'On Windows 8.1/2012R2.' } }; post   = { 1 }; }
  @{ name    =   'remove_hiberfil.sys';
      script = {
        Gwmi Win32_LogicalDisk | ?{ $_.DriveType -eq 3 } | ?{
          Test-Path (Join-Path $_.DeviceID 'hiberfil.sys')
        } | %{ rm -Force -Verbose:$VerbosePreference (Join-Path $_.DeviceID 'hiberfil.sys') }
      };
      pre    = { 1 };
      post   = {
        Gwmi Win32_LogicalDisk | ?{ $_.DriveType -eq 3 } | ?{
          if (Test-Path (Join-Path $_.DeviceID 'hiberfil.sys')) {
            Throw "$($_.DeviceID)\hiberfil.sys found."
          }
        }
      }; }
  @{ name    =   'clear_bitsadmin_cache';
      script = { & bitsadmin.exe /cache /clear };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'remove_temp_files';
      script = { rm -Force -Verbose:$VerbosePreference -Recurse (Join-Path $Env:TEMP '*') -ea 0};
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'remove_windows_temp_files';
      script = { rm -Force -Verbose:$VerbosePreference -Recurse (Join-Path $Env:WINDIR 'TEMP\*') -ea 0 };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'remove_windows_downloaded_program_files';
      script = { rm -Force -Verbose:$VerbosePreference -Recurse (Join-Path $Env:WINDIR 'Downloaded Program Files\*') -ea 0 };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'remove_windows_prefetch_files';
      script = { rm -Force -Verbose:$VerbosePreference -Recurse (Join-Path $Env:WINDIR 'Prefetch\*') -ea 0 };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'invoke_dism_service_pack_cleanup';
      script = { & dism.exe /online /cleanup-image /spsuperseded };
      pre    = { Get-Command dism.exe -ea 1 }; post   = { 1 }; }
  @{ name    =   'remove_ntuninstall_files';
      script = {
        ls -ea 0 -Force (Join-Path $Env:WINDIR '$NT*install*') -Recurse | %{
          rm -ea 0 -Recurse -Force -Verbose:$VerbosePreference $_
        }
      };
      pre    = { ls (Join-Path $Env:WINDIR '$NT*install*') -ea 1 }; post   = { 1 }; }
  @{ name    =   'remove_software_distribution_download_files';
      script = {
        Get-Service *inst* | Stop-Service -Verbose:$VerbosePreference -ea 0
        Sleep 2
        try { rm -Force -Recurse (Join-Path $Env:WINDIR 'SoftwareDistribution\Download') } catch {}
      };
      pre    = { Test-Path (Join-Path $Env:WINDIR 'SoftwareDistribution\Download') }; post   = { 1 }; }
  @{ name    =   'remove_windows_installer_patchcache_files';
      script = {
        Get-Service *inst* | Stop-Service -Verbose:$VerbosePreference -ea 0
        Sleep 2
        rm -Force -Verbose:$VerbosePreference -recurse (Join-Path $Env:WINDIR 'Installer\$PatchCache$\*')  -ea 0
      };
      pre    = { Test-Path (Join-Path $Env:WINDIR 'Installer\$PatchCache$') }; post   = { 1 }; }
  @{ name    =   'disable_indexing_on_local_drives';
      script = {
        Gwmi Win32_LogicalDisk | ?{ $_.DriveType -eq 3 } | %{
          Get-WmiObject Win32_Volume -Filter "DriveLetter='$($_.DeviceID)'" | ?{
            $_.IndexingEnabled
          } | %{
            $_ | Set-WmiInstance -Arguments @{IndexingEnabled=$False} -Verbose:$VerbosePreference
          }
        }
      };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'start_service_pack_cleanup_tool';
      script = { Start-Process vsp1cln.exe -ArgumentList '/quiet' -Wait -NoNewWindow };
      pre    = { Get-Command 'vsp1cln.exe' -ea 1 }; post   = { 1 }; }
  @{ name    =   'start_component_cleanup_tool';
      script = { Start-Process compcln.exe -argumentlist '/quiet' -wait -NoNewWindow };
      pre    = { Get-Command 'compcln.exe' -ea 1 }; post   = { 1 }; }
# @{ name    =   'start_sfc_integrity_check';
#     script = { try { Start-SFC -scannow -Verbose:$VerbosePreference } catch {
#                       Write-Warning "SFC Failed to complete :$_"
#                     }};
#     pre    = { 1 }; post   = { 1 }; }
# @{ name    =   'start_defrag_on_local_drives';
#     script = {
#       Get-Service defragsvc -ea 0 | Set-Service -StartupType Manual -PassThru | Start-Service -Verbose:$VerbosePreference
#       Start-Process defrag.exe -ArgumentList @('-f','-v','c:') -wait -NoNewWindow
#     };
#     pre    = { 1 }; post   = { 1 }; }
  #@{ name    =   'install_sdelete';
  #    script = {
  #      reg.exe add 'HKCU\SOFTWARE\Sysinternals\C' /v EulaAccepted /t REG_DWORD /d 1 /f
  #      cp (Join-Path $Env:IPBaseDir "bin/SysInternals\sdelete.exe") "$Env:OLBIN" -Verbose:$VerbosePreference -Force -ea 1
  #    };
  #    pre    = { 1 }; post   = { 1 }; }
  # @{ name    =   'start_contig_on_local_drives';
  #     script = {
  #       Gwmi Win32_LogicalDisk | ?{ $_.DriveType -eq 3 } | %{ & contig.exe -a -s "$($_.DeviceID)" }
  #     };
  #     pre    = { 1 }; post   = { 1 }; }
  # @{ name    =   'start_contig_on_local_drives_special_ntfs_files';
  #     script = {
  #       cp (Join-Path $Env:IPBaseDir "bin/SysInternals\contig.exe") "$Env:OLBIN" -Verbose:$VerbosePreference -Force
  #       reg.exe add HKCU\SOFTWARE\Sysinternals\C /v EulaAccepted /t REG_DWORD /d 1 /f
  #       Gwmi Win32_LogicalDisk | ?{ $_.DriveType -eq 3 } | %{
  #         $Drive = $_.DeviceID
  #         '$mft','$LogFile','$Volume','$Attrdef','$Bitmap','$Boot','$BadClus','$Secure','$UpCase','$Extend' | %{
  #           & contig.exe -v -s (Join-Path $Drive $_)
  #         }
  #       }
  #     };
  #     pre    = { 1 }; post   = { 1 }; }
  # @{ name    =   'start_precompact';
  #     script = {
  #       cp -force -Verbose:$VerbosePreference (@(gcm precompact.exe)[0].Definition) $Env:TEMP
  #       Start-Process "$Env:TEMP\precompact.exe" -argumentlist '-silent' -wait -NoNewWindow
  #       rm -Force "$Env:TEMP\precompact.exe" -Verbose:$VerbosePreference
  #     };
  #     pre    = { Get-Command 'precompact.exe' -ea 1 }; post   = { 1 }; }
  # @{ name    =   'install_sdelete';
  #     script = {
  #       reg.exe add 'HKCU\SOFTWARE\Sysinternals\SDelete' /v EulaAccepted /t REG_DWORD /d 1 /f
  #       cp (Join-Path $Env:IPBaseDir "bin/SysInternals\sdelete.exe") "$Env:OLBIN" -Verbose:$VerbosePreference -Force
  #     };
  #     pre    = { 1 }; post   = { 1 }; }
  # @{ name    =   'start_sdelete_to_zero_free_space_on_local_disks';
  #     script = {
  #       Start-Process 'sdelete.exe' -ArgumentList @('-a', '-c', '-r', '-z', '-p', '2', 'c:') -Wait -NoNewWindow
  #     };
  #     pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'eject_cdrom_devices';
      script = { Dismount-CDROMDevice -All -Verbose:$VerbosePreference };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'gpupdate_update_force';
      script = { gpupdate.exe /force /boot /sync };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'bcdedit_set_bootlog_off';
      script = { bcdedit.exe /set bootlog no };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'bcedit_set_quietboot_on';
      script = { bcdedit.exe /set quietboot on };
      pre    = { 1 }; post   = { 1 }; }
  # @{ name    =   'enable_automatic_managed_pagefile';
  #     script = { Enable-AutomaticManagedPagefile -Verbose:$VerbosePreference };
  #     pre    = { $os = gwmi win32_operatingsystem; if ($os.version -imatch '^5\.1'){ throw 'On Windows XP/2003.' } }; post   = { 1 }; }
  # @{ name    =   'enable_clear_pagefile_on_shutdown';
  #     script = { Disable-ClearPageFileAtShutdown -Verbose:$VerbosePreference };
  #     pre    = { 1 }; post   = { 1 }; }
  # @{ name    =   "guest_delete_window_position_key-$(get-date -uformat %s)";
  #     script = {
  #       $Local:ErrorActionPreference = "CONTINUE"
  #       & reg.exe add     "HKCU\Console" /v WindowSize     /t  0x00400090   /d REG_DWORD /f
  #       & reg.exe delete  "HKCU\Console" /v WindowPosition /f
  #     };
  #     pre    = { 1 }; post   = { 1 }; }
  # TODO
  # @{ name    =  'register_machine_startup_script_engine';
  #     script = { 1; };
  #     pre    = { 1 }; post   = { 1 }; }
  @{ name    =   'clear_event_logs';
      script = { Get-EventLog -LogName * | %{ Clear-EventLog -LogName $_.Log -Verbose:$VerbosePreference } };
      pre    = { 1 }; post   = { 1 }; }
  @{ name    =  "register_vm_guest_tools_install_script-$(get-date -uformat %s)";
      script = {
        # TODO : ModuleUtils ought to install these automatically
        $ProgramDataDir = if ($Env:PROGRAMDATA) {$Env:PROGRAMDATA} else {Join-Path "$Env:SYSTEMDRIVE" "ProgramData"}
        $TargetModuleBaseDir = Join-Path $ProgramDataDir "Citrix\PowerShell\Modules\"
        mkdir $TargetModuleBaseDir -Force | Out-Null
        'CDRom','XenTools','VMGuestTools','HyperVIC','VMWareTools','ModuleUtils','SystemUtils' | %{
          cp -Verbose:$VerbosePreference -Recurse -Force "$Env:IPBaseDir\Modules\$_\" "$TargetModuleBaseDir\"
        }
        & "$TargetModuleBaseDir\VMGuestTools\Tests\Install-VMGuesttools.ps1" -SelfInstall
      };
      pre    = { 1 }; post   = { 1 }; }
),

# Stage 4
@(
  @{ name    =   'restart_for_stage_4';
      script = { & shutdown.exe -r -t 2 };
      pre    = { 1 }; post   = { 1 }; }
)


#  DisablePagingExecutive to 1