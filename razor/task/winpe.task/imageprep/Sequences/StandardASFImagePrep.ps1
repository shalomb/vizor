# Powershell script - Sequences/StandardASFImagePrep.ps1
# Powershell prologue, documentation, etc moved to the bottom.

# This file is not to be meant to run directly but rather as an
# imput to the functions in the SystemUtils modules.

[CmdletBinding()]    
Param()


Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0


# [Boolean]$VerbosePreference="SilentlyContinue"
$ErrorActionPreference="STOP"


# Init - Import all modules required by tasks enclosed within.
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
# Import-Module HyperVIC    
# Import-Module XenTools    
# Import-Module VMWareTools 

# Import-Module PSRemoteRegistry
# Import-Module PsUrl           

# Tasks Outstanding
#  Enable Pagefile on first startup 
#  run clr_optimization_v2.0* to completion

# Define the environment for the run
$Env:OLBASE = "$Env:SystemDrive\ProgramData\OneLab"
$Env:OLCONF = Join-Path $Env:OLBASE "conf"
$Env:OLBIN  = Join-Path $Env:OLBASE "bin"
$Env:OLLOG  = Join-Path $Env:OLBASE "log"
$Env:OLIP   = Join-Path $Env:OLLOG  "ImagePrep"
$Env:KMS_SERVER = 'camesvwkms01.eng.citrite.net'
$Env:KMS_PORT = '1688'

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
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'sync_ntp_time_stage_0';
      script = { Sync-W32Time };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'enable_crash_control_crash_dump_full';
      script = { Enable-CrashControlCrashDump -Value 1 -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'enable_crash_control_nmi_crash_dump';
      script = { Enable-NMICrashDump -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'enable_crash_control_autoreboot';
      script = { Enable-CrashControlAutoReboot -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'enable_crash_control_dump_file_overwrite';
      script = { Enable-CrashControlDumpFileOverWrite -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'enable_crash_control_send_alert';
      script = { Enable-CrashControlSendAlert -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'enable_crash_control_log_system_event';
      script = { Enable-CrashControlLogEvent -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'enable_crash_control_always_keep_memory_dump';
      script = { Enable-CrashControlAlwaysKeepMemoryDump -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'disable_first_logon_animations';
      script = { Disable-FirstLogonAnimations };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'uninstall_msmsgs_startup_commands';
      pre    = { if (-not((Get-Version).CurrentVersion -imatch '5.1')){ throw 'Not on Windows XP/2003.' } };
      script = { Get-StartupCommand | ?{ $_.Caption -imatch 'msmsgs' } | Uninstall-StartupCommand -Verbose:$VerbosePreference };
      post   = { 1 }; }
  @{ name    =   'uninstall_ctfmon_startup_commands';
      pre    = { if (-not((Get-Version).CurrentVersion -imatch '5.1')){ throw 'Not on Windows XP/2003.' } };
      script = { Get-StartupCommand | ?{ $_.Caption -imatch 'ctfmon.exe' } | Uninstall-StartupCommand -Verbose:$VerbosePreference };
      post   = { 1 }; }
  @{ name    =   'uninstall_welcomecenter_startup_commands';
      pre    = { $os = gwmi win32_operatingsystem; if (-not($os.version -imatch '^(?:5\.0|6\.0)')){} };
      script = { Get-StartupCommand | ?{ $_.Caption -imatch 'welcomecenter' } | Uninstall-StartupCommand -Verbose:$VerbosePreference };
      post   = { 1 }; }
  @{ name    =   'uninstall_sidebar_startup_commands';
      pre    = { $os = gwmi win32_operatingsystem; if (-not($os.version -imatch '^6\.[01]')){ Write-Warning 'Not on Windows Vista/7.' } };
      script = { Get-StartupCommand | ?{ $_.Caption -imatch 'sidebar' } | Uninstall-StartupCommand -Verbose:$VerbosePreference };
      post   = { 1 }; }
  @{ name    =   'uninstall_windows_defender_startup_commands';
      pre    = { 1 };
      script = { Get-StartupCommand | ?{ $_.Caption -imatch 'windows defender' } | Uninstall-StartupCommand -Verbose:$VerbosePreference };
      post   = { 1 }; }
  @{ name    =   'disable_server_manager';
      script = { Disable-ServerManager -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'set_high_performance_power_scheme';
      script = { Set-PowerSchemeOptimizations -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'disable_remote_desktop';
      script = { Disable-RemoteDesktop -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'disable_windows_sidebar';
      script = { Disable-WindowsSidebar -Verbose:$VerbosePreference };
      pre    = { $os = gwmi win32_operatingsystem; if (-not($os.version -imatch '^6\.0')){ throw 'Not on Windows Vista.' } };
      post   = { 1 }; }
  @{ name    =   'set_w32tm_service_autostart';
      script = {  Get-Service -Name W32Time | Set-Service -StartupType Automatic -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'disable_screensaver';
      script = { Disable-ScreenSaver -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'create_local_administrator';
      script = { New-LocalAdministrativeUser -Username "Administrator" -Password "***REMOVED***" -Verbose:$VerbosePreference };
      pre    = { if ( (Get-CurrentDomain).PartOfDomain ) { Throw "Computer is a domain member." } };
      post   = { 1 }; }
  # Backup administrator
  @{ name    =   'create_local_administrator_citrix';
      script = { New-LocalAdministrativeUser -Username "citrix" -Password "***REMOVED***" -Verbose:$VerbosePreference };
      pre    = { if ( (Get-CurrentDomain).PartOfDomain ) { Throw "Computer is a domain member." } };
      post   = { 1 }; }
  @{ name    =   'initialize_sysinternals_tools';
      script = { SystemUtils\Initialize-SysInternals };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'disable_system_restore';
      script = { Disable-SystemResoreOnLocalDrives -ea 0 };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'set_cscript_as_wsh_host';
      script = { Set-WSHScriptHost "CScript" };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'enable_show_desktop_on_logon';
      script = { Enable-ShowDesktopOnLogon };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'update_powershell_help';
      script = { Update-Help -Verbose:$VerbosePreference };
      pre    = { $psver=$PSVersionTable.PSversion; if (-not($psver -ge 3.0)){ throw 'Not on PowerShell >= 3.0.' } };
      post   = { 1 }; }
  @{ name    =   'enable_windows_updates';
      script = { Enable-WindowsUpdates };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'install_dotnet35_on_2008r2';
      script = { if (-not(Test-Path "$Env:WINDIR\Microsoft.Net\Framework*\v3*")) { 
                    Import-Module ServerManager -Verbose:$VerbosePreference; Add-WindowsFeature as-net-framework -Verbose:$VerbosePreference 
                  }  
      };
      pre    = { $os = gwmi win32_operatingsystem; if (-not($os.version -imatch '^6.1.7601')){ throw 'Not on Windows 2008 R2.' } };
      post   = { 1 }; }
  @{ name    =   'install_windows_updates';
      script = { Search-WindowsUpdate -ImportantOnly -Verbose:$VerbosePreference | Install-WindowsUpdate -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'invoke_windows_defender_signature_update';
      script = { Invoke-WindowsDefenderUpdate -Verbose:$VerbosePreference };
      pre    = { $os = gwmi win32_operatingsystem; if ($os.version -imatch '^(?:6\.[1-9])'){ throw 'On Windows 8.1/2012R2.' } };
      post   = { 1 }; }
  @{ name    =   'disable_windows_updates';
      script = { Disable-WindowsUpdates };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'disable_screen_savers';
      script = { Disable-ScreenSaver };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'disable_auto_reboot_on_system_failure';
      script = { Disable-AutoRebootOnSystemFailure };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'set_user_preferences';
      script = { Set-UserPreferences -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'disable_device_autorun';
      script = { Disable-AutoRun };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'disable_non-essential_scheduled_tasks';
      script = { Disable-NonEssentialScheduledTasks };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name  =  'set_service_helpsvc.help_and_support_to_startuptype_manual'; 
      script = { Set-Service 'helpsvc' -StartupType 'Manual' -ea 0 -verb:$VerbosePreference };
      pre = { 1 }; post = { 1 }; } 
  @{ name  =  'set_service_defragsvc.optimize_drives_to_startuptype_disabled'; 
      script = { Set-Service 'defragsvc' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference };
      pre = { 1 }; post = { 1 }; } 
  @{ name  =  'set_service_ersvc.error_reporting_to_startuptype_manual'; 
      script = { Set-Service 'ERSvc' -StartupType 'Manual' -ea 0 -verb:$VerbosePreference };
      pre = { 1 }; post = { 1 }; } 
  @{ name  =  'set_service_wersvc.windows_error_reporting_service_to_startuptype_manual'; 
      script = { Set-Service 'WerSvc' -StartupType 'Manual' -ea 0 -verb:$VerbosePreference };
      pre = { 1 }; post = { 1 }; } 
  @{ name  =  'set_service_windefend.windows_defender_service_to_startuptype_disabled'; 
      script = { Set-Service 'WinDefend' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference };
      pre = { 1 }; post = { 1 }; } 
  @{ name  =  'set_service_wscsvc.security_center_to_startuptype_manual'; 
      script = { Set-Service 'wscsvc' -StartupType 'Manual' -ea 0 -verb:$VerbosePreference };
      pre = { 1 }; post = { 1 }; } 
  @{ name  =  'set_service_wsearch.windows_search_to_startuptype_disabled'; 
      script = { Set-Service 'WSearch' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference };
      pre = { 1 }; post = { 1 }; } 
  @{ name  =  'set_service_wuauserv.automatic_updates_to_startuptype_disabled'; 
      script = { Set-Service 'wuauserv' -StartupType 'Disabled' -ea 0 -verb:$VerbosePreference };
      pre = { 1 }; post = { 1 }; } 
  @{ name  =  'set_service_wzcsvc.wireless_to_startuptype_manual'; 
      script = { Set-Service 'WZCSVC' -StartupType 'Manual' -ea 0 -verb:$VerbosePreference };
      pre = { 1 }; post = { 1 }; } 
  @{ name  =  'set_service_tapisrv.telephony_to_startuptype_manual'; 
      script = { Set-Service 'TapiSrv' -StartupType 'Manual' -ea 0 -verb:$VerbosePreference };
      pre = { 1 }; post = { 1 }; } 
  @{ name  =  'set_service_bits.background_intelligent_transfer_services_to_startuptype_manual'; 
      script = { Set-Service 'BITS' -StartupType 'Manual' -ea 0 -verb:$VerbosePreference };
      pre = { 1 }; post = { 1 }; } 
  @{ name  =  'set_service_remoteregistry.remote_registry_to_startuptype_manual'; 
      script = { Set-Service 'RemoteRegistry' -StartupType 'Manual' -ea 0 -verb:$VerbosePreference };
      pre = { 1 }; post = { 1 }; } 
  @{ name    =   'disable_hibernation';
      script = {  try { & powercfg.exe -h off } catch {} };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'disable_automatic_managed_pagefile';
      script = { Disable-AutomaticManagedPagefile -Verbose:$VerbosePreference };
      pre    = { $os = gwmi win32_operatingsystem; if ($os.version -imatch '^5\.1'){ throw 'On Windows XP/2003.' } };
      post   = { 1 }; }
  @{ name    =   'enable_clear_pagefile_at_shutdown';
      script = { Enable-ClearPagefileAtShutdown -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'delete_pagefiles';
      script = { Get-Pagefile | Remove-Pagefile -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'enable_automatic_administrative_login';
      script = { Set-AutoAdminLogon -DefaultUserName "Administrator" -DefaultPassword "***REMOVED***" -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
),


# Stage 1
@(
  @{ name    =   'restart_for_stage_2';
      script = { & shutdown.exe -r -t 2 };
      pre    = { 1 };
      post   = { 1 }; }
),


# Stage 2
@(
  @{ name    =   'set_timezone_gmt';
      pre    = { (Gwmi Win32_TimeZone) -imatch '^GMT Standard Time$' };
      script = { Get-TimeZone -TimeZoneName 'GMT Standard Time' | Set-TimeZone -Verbose:$VerbosePreference };
      post   = { (Gwmi Win32_TimeZone) -imatch '^GMT Standard Time$' }; }
  @{ name    =   'uninstall_browserchoice_startup_command';
      pre    = { 1 };
      script = { Get-StartupCommand | ?{ $_.Caption -imatch 'BrowserChoice' } | Uninstall-StartupCommand -Verbose:$VerbosePreference };
      post   = { 1 }; }
  @{ name    =   'sync_ntp_time_stage_2';
      script = { Sync-W32Time };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'install_taskbar_shortcut_items';
      script = { @("powershell", "cmd", "taskmgr", "eventvwr", "mmc","psr") | %{ 
          if (gcm $_ -ea 0) { try { Install-DesktopShortcut -Command "$_" } catch {} } 
        }
      };
      pre    = { 1; };
      post   = { 1 }; }
  @{ name    =   'set_kms_server'; 
      script = { & slmgr.vbs -skms "${Env:KMS_SERVER}:${Env:KMS_PORT}" };
      pre    = { $os = gwmi win32_operatingsystem; if ($os.version -imatch '^5\.1'){ throw 'On Windows XP/2003.' } };
      post   = { 1 }; }
  @{ name    =   'activate_windows';
      script = { Invoke-WindowsActivation };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'add_powershell_assemblies_to_ngen_queue';
      script = { Add-AssemblyToNgenQueue -CurrentDomainAssemblies -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'start_ngen_queued_tasks';
      script = { Start-NgenQueuedTasks -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'invoke_winmgmt_repository_reset';
      script = { Invoke-WinMgmt -ResetRepository };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'invoke_winmgmt_repository_verify';
      script = { Invoke-WinMgmt -VerifyRepository };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'invoke_windows_defender_full_scan';
      script = { Invoke-WindowsDefenderScan -Full -Verbose:$VerbosePreference };
      pre    = { $os = gwmi win32_operatingsystem; if ($os.version -imatch '^(?:6\.[1-9])'){ throw 'On Windows 8.1/2012R2.' } };
      post   = { 1 }; }
  @{ name    =   'collect_windows_defender_files';
      script = { Invoke-WindowsDefenderCommand -MPCmdRunArgs @('-GetFiles') -Verbose:$VerbosePreference };
      pre    = { $os = gwmi win32_operatingsystem; if ($os.version -imatch '^(?:6\.[1-9])'){ throw 'On Windows 8.1/2012R2.' } };
      post   = { 1 }; }
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
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'remove_temp_files'; 
      script = { rm -Force -Verbose:$VerbosePreference -Recurse (Join-Path $Env:TEMP '*') -ea 0};
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'remove_windows_temp_files'; 
      script = { rm -Force -Verbose:$VerbosePreference -Recurse (Join-Path $Env:WINDIR 'TEMP\*') -ea 0 };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'remove_windows_downloaded_program_files'; 
      script = { rm -Force -Verbose:$VerbosePreference -Recurse (Join-Path $Env:WINDIR 'Downloaded Program Files\*') -ea 0 };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'remove_windows_prefetch_files'; 
      script = { rm -Force -Verbose:$VerbosePreference -Recurse (Join-Path $Env:WINDIR 'Prefetch\*') -ea 0 };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'invoke_dism_service_pack_cleanup';
      script = { & dism.exe /online /cleanup-image /spsuperseded };
      pre    = { Get-Command dism.exe -ea 1 };
      post   = { 1 }; }
  @{ name    =   'remove_ntuninstall_files'; 
      script = { 
        ls -ea 0 -Force (Join-Path $Env:WINDIR '$NT*install*') -Recurse | %{
          rm -ea 0 -Recurse -Force -Verbose:$VerbosePreference $_ 
        }
      };
      pre    = { ls (Join-Path $Env:WINDIE '$NT*install*') -ea 1 };
      post   = { 1 }; }
  @{ name    =   'remove_software_distribution_download_files';
      script = { 
        Get-Service *inst* | Stop-Service -Verbose:$VerbosePreference -ea 0
        Sleep 2
        rm -Force -Recurse (Join-Path $Env:WINDIR 'SoftwareDistribution\Download') 
      };
      pre    = { Test-Path (Join-Path $Env:WINDIR 'SoftwareDistribution\Download') };
      post   = { 1 }; }
  @{ name    =   'remove_windows_installer_patchcache_files';
      script = { 
        Get-Service *inst* | Stop-Service -Verbose:$VerbosePreference -ea 0
        Sleep 2
        rm -Force -Verbose:$VerbosePreference -recurse (Join-Path $Env:WINDIR 'Installer\$PatchCache$\*')  -ea 0
      };
      pre    = { Test-Path (Join-Path $Env:WINDIR 'Installer\$PatchCache$') };
      post   = { 1 }; }
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
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'start_service_pack_cleanup_tool'; 
      script = { Start-Process vsp1cln.exe -ArgumentList '/quiet' -Wait -NoNewWindow };
      pre    = { Get-Command 'vsp1cln.exe' -ea 1 };
      post   = { 1 }; }
  @{ name    =   'start_component_cleanup_tool'; 
      script = { Start-Process compcln.exe -argumentlist '/quiet' -wait -NoNewWindow };
      pre    = { Get-Command 'compcln.exe' -ea 1 };
      post   = { 1 }; }
  @{ name    =   'start_sfc_scannow';
      script = { Start-SFC -scannow -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'start_defrag_on_local_drives';
      script = { 
        Get-Service defragsvc -ea 0 | Set-Service -StartupType Manual -PassThru | Start-Service -Verbose:$VerbosePreference
        Gwmi Win32_LogicalDisk | ?{ $_.DriveType -eq 3 } | %{
          $DriveLetter = $_.DeviceId
          Start-Process defrag.exe -ArgumentList @('-f','-v',$DriveLetter) -wait -NoNewWindow
        }
      };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'start_contig_on_local_drives';
      script = {
        cp (Join-Path $Env:IPBaseDir "bin/SysInternals\contig.exe") "$Env:OLBIN" -Verbose:$VerbosePreference -Force
        reg.exe add HKCU\SOFTWARE\Sysinternals\C /v EulaAccepted /t REG_DWORD /d 1 /f
        Gwmi Win32_LogicalDisk | ?{ $_.DriveType -eq 3 } | %{ & contig.exe -a -s "$($_.DeviceID)" }
      };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'start_contig_on_local_drives_special_ntfs_files';
      script = {
        cp (Join-Path $Env:IPBaseDir "bin/SysInternals\contig.exe") "$Env:OLBIN" -Verbose:$VerbosePreference -Force
        reg.exe add HKCU\SOFTWARE\Sysinternals\C /v EulaAccepted /t REG_DWORD /d 1 /f
        Gwmi Win32_LogicalDisk | ?{ $_.DriveType -eq 3 } | %{ 
          $Drive = $_.DeviceID
          '$mft','$LogFile','$Volume','$Attrdef','$Bitmap','$Boot','$BadClus','$Secure','$UpCase','$Extend' | %{
            & contig.exe -v -s (Join-Path $Drive $_) 
          }
        }
      };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'start_precompact'; 
      script = { 
        cp -force -Verbose:$VerbosePreference (@(gcm precompact.exe)[0].Definition) $Env:TEMP
        Start-Process "$Env:TEMP\precompact.exe" -argumentlist '-silent' -wait -NoNewWindow
        rm -Force "$Env:TEMP\precompact.exe" -Verbose:$VerbosePreference
      };
      pre    = { Get-Command 'precompact.exe' -ea 1 };
      post   = { 1 }; }
  @{ name    =   'install_sdelete';
      script = { 
        reg.exe add 'HKCU\SOFTWARE\Sysinternals\SDelete' /v EulaAccepted /t REG_DWORD /d 1 /f
        cp (Join-Path $Env:IPBaseDir "bin/SysInternals\sdelete.exe") "$Env:OLBIN" -Verbose:$VerbosePreference -Force
      };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'start_sdelete_to_zero_free_space_on_local_disks';
      script = { 
        Gwmi Win32_LogicalDisk | ?{ $_.DriveType -eq 3 } | %{ 
          Start-Process 'sdelete.exe' -ArgumentList @('-a', '-c', '-r', '-z', '-p', '2', "$($_.DeviceID)\") -Wait -NoNewWindow
        }
      };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'show_w32tm_status';
      script = { Show-W32tmStatus -Status };
      pre    = { 1 };
      post   = { 1 }; }
),


# Stage 3
@(
  @{ name    =   'restart_for_stage_3';
      script = { & shutdown.exe -r -t 2 };
      pre    = { 1 };
      post   = { 1 }; }
),


# Stage 4
@(
  @{ name    =   'sync_ntp_time_stage_4';
      script = { Sync-W32Time };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'eject_cdrom_devices';
      script = { Dismount-CDROMDevice -All -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'clear_event_logs';
      script = { Get-EventLog -LogName * | %{ Clear-EventLog -LogName $_.Log -Verbose:$VerbosePreference } };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'gpupdate_update_force';
      script = { gpupdate.exe /force /boot /sync };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'enable_pagefile_properties_for_xp';
      script = { 
        $pfs_i = 0.3 * ((gwmi win32_computersystem).TotalPhysicalMemory / 1MB)
        New-Pagefile -Pagefile 'c:\pagefile.sys' -InitialSize $pfs_i -ea 0
      };
      pre    = { $os = gwmi win32_operatingsystem; if (-not($os.version -imatch '^5\.1')){ throw 'Not on Windows XP/2003.' } };
      post   = { 1 }; }
  @{ name    =   'enable_automatic_managed_pagefile';
      script = { Enable-AutomaticManagedPagefile -Verbose:$VerbosePreference };
      pre    = { $os = gwmi win32_operatingsystem; if ($os.version -imatch '^5\.1'){ throw 'On Windows XP/2003.' } };
      post   = { 1 }; }
  @{ name    =   'enable_clear_pagefile_on_shutdown';
      script = { Enable-ClearPageFileAtShutdown -Verbose:$VerbosePreference };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   "guest_delete_window_position_key-$(get-date -uformat %s)";
      script = { 
        $Local:ErrorActionPreference = "CONTINUE"
        & reg.exe add     "HKCU\Console" /v WindowSize     /t  0x00400090   /d REG_DWORD /f
        & reg.exe delete  "HKCU\Console" /v WindowPosition /f
      };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =  'register_machine_startup_script_engine';
      script = { 1; };
      pre    = { 1 };
      post   = { 1 }; }
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
      pre    = { 1 };
      post   = { 1 }; }
)

# Stage 4
@(
  @{ name    =   'restart_for_stage_4';
      script = { & shutdown.exe -r -t 2 };
      pre    = { 1 };
      post   = { 1 }; }
)

<#
.SYNOPSIS
Standard ASF Image Preparation Sequence

.DESCRIPTION
This script represents a collection of image preparation tasks broken down
into individual stages which are further broken down  into individual
tasks.   

This script is NOT to be invoked directly but rather through the 
ImageMaintenance\Get-Task function. Please refer to the help of the 
ImageMaintenance for more details.

Please refer to the NOTES section (get-help <this file> -full) for notes
on the datastructures used in this sequence and so how you may create
your own.

Several minor issues exist, please refer to the NOTES section for details.

.NOTES
This script is expected to return a sequence to the caller.
The caller is usually ImageMaintenance\Get-Task but can be any 
powershell construct that understands the datastructure.

A sequence is defined as a collection of stages. It is represented as
an array of arrays (stages).

A stage is defined as a collection of tasks. It is represented as an
array of hashes (tasks).

A task is defined here an atomic activity. It is represented as a
simple hash table.

As a whole, the sequence is represented as an array of arrays of hashes.

This datastructure allows for the script to contain a set of stages,
each of which has a collection of tasks to be run in that stage.
This datastructure also allows for filtering on tasks to be run

All tasks within a stage must pass for a stage to completed.

All stages must pass for the sequence to be complete (and so for the
image preparation to be complete).

A task is represented here hash with a 'script' key contain the
powershell scriptblock which contains the powershell code that will carry
out the task - and so effect change in the system. A 'script' should fail
if it cannot successfully execute the enclosing code - and so cause the
sequence to fail early.

A task also has other keys 'pre' and 'post' which are also scriptblocks
which control code executed before/after the 'script' key is invoked.

Code in the 'pre' block act as conditionals to the 'script' block i.e.
to allow or deny a 'script' block execution.

'pre' can also enclose scriptlets that prepare (in a failsafe fashion) the
state of the system to allow for the 'script' to run - just as long as
the scriptlets return a true value.

'post' encloses a scriptlet used to carry out clean-up tasks or seal the
state of the system - also in a failsafe fashion.

'pre' and 'post' are currently required to be defined and must have a
minimum value of $True or 1.

RATIONALE OF SEQUENCE BREAKDOWN
-------------------------------
A collection of tasks can be written as a simple powershell script that
has the powershell interpreter step through the script and invoke the 
tasks but this approach has a number of problems and limitations.

  * It is hard to report on the state/status of individual tasks without
    wrapping each task up in a reporting function.

  * Ensuring idempotency of a task hard to guarantee when the script is 
    rerun. A subsequent invocation of a task can be unsafe or dangerous.

  * Building logic in the script to filter out tasks for a particular 
    objective or invocation becomes quite complex.

As the datastructure in a sequence such as this is just a collection of
objects, an orthogonal mechanism such as a task processor can be used to
process an object collection and circumvent the above problems.


EXAMPLE OF A MINIMAL SEQUENCE
-----------------------------

# Stage 0 - Hello World and Install DotNet 3.5
@(
  @{ name     = 'HelloWorld';
      script  = { Write-Host "Hello world!" }; 
      pre = 1; post = 1; },
  @{ name = 'HelloWorld Only If On Win7 or greater'; 
      script = { Write-Host "Hello world from a newer OS!" };
      pre = { (Gwmi Win32_OperatingSystem).Version -ge 6.1 };
      post = 1; },
  @{ name = 'Install AD Certificate Service Only If On 2012 And WINS Not Installed'; 
      script = { ipmo ServerManager; Add-WindowsFeature AD-Certificate };
      pre = { 
        $Test1 = ((Gwmi Win32_OperatingSystem).Caption -ilike "2012") 
        $Test2 = -not((Get-WindowsFeature WINS).Installed)
        $Test1 -and $Test2 # this evaluation to true determines if 'script' gets run
      };
      post = 1; },
  @{ name='CleanUpTemp';
      script={ rm -Force "$Env:TEMP\*" }; 
      pre=1; 
      post=1; },
  @{ name='InstallDotNet35andCleanup';  
      script={ Import-Module ServerManager; Add-WindowsFeature NET-Framework-Features };
      pre=1;
      post= { rm -Force "$Env:TEMP\*" }; }
),

# Stage 1 - Reboot the computer after dotnet was installed
@(
  @{ name='RebootToEnterStage2';
      script={ & shutdown.exe -r }; pre=1; post=1; },
),

# Stage 2 - Install some software
@(
  @{ name='Sync Windows Time';
      script={ & w32tm.exe /resync }; pre=1; post=1; },
  @{ name='InstallSoftwareOffANetworkShare';
      script={ \\example.com\share\software\someinstaller.exe -args }; 
      pre={ & ipconfig.exe /flushdns };  # This may fail but is harmless
      post=1; 
      }
),

# Stage 3 - ClearLogs and shutdown
@(
  @{ name='ClearEventViewerEvents';
      script = { Get-EventLog -LogName * | %{ Clear-EventLog -LogName $_.Log } };
      pre = 1;
      post = 1; }
  @{ name='ShutDownComputerToPrepareImageDeployment';
      script={ & shutdown.exe -s }; pre=1; post=1; }
)


KNOWN ISSUES
------------

A bug exists currently where if the number of elements in the sequence array 
is less than 2, ImageMaintenance\Get-Tasks will fail to process this sequence file.
To workaround, simply create another empty element at the end of the collection.

#>


