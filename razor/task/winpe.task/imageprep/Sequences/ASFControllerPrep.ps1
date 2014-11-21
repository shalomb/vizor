# PowerShell

Set-StrictMode -Version 2
$ErrorActionPreference="STOP"
Set-PSDebug -Trace 0

Import-Module RDP             -Verbose:$VerbosePreference
Import-Module ServerManager   -Verbose:$VerbosePreference

$Env:OLBASE = "$Env:PROGRAMDATA\OneLab"
$Env:OLCONF = Join-Path $Env:OLBASE "conf"
$Env:OLBIN  = Join-Path $Env:OLBASE "bin"
$Env:OLLOG  = Join-Path $Env:OLBASE "log"
$Env:OLIP   = Join-Path $Env:OLLOG  "ImagePrep"

# Stage 0
@(
  @{ name    =   'create_onelab_support_directory_hierarchy';
      script = {
        $Env:OLBASE,$Env:OLCONF,$Env:OLBIN,$Env:OLLOG,$Env:OLIP | %{
          mkdir -Force -Verbose $_ | Out-Null
        }
      };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'install_python_2.7';
      script = { 
        $InstallWizardArgs = @('/i',"$Script:PythonMsi",'/liwearucmopvx!',"$Env:OLIP\python_install.log",'/qr')
        Write-Verbose "InstallWizardArgs : $InstallWizardArgs"
        $process = Start-Process -FilePath $(Join-Path "$Env:WINDIR\System32" msiexec.exe) `
                    -ArgumentList $InstallWizardArgs -Wait -PassThru
        $Process.ExitCode
      };
      pre    = { 
        Test-Path ($Script:PythonMsi = '\\camautonfs01.eng.citrite.net\software\ActiveState\Python\2.7\ActivePython-2.7.2.5-win64-x64.msi')
      };
      post   = { & "$Env:SystemDrive\Python27\python.exes" -V }; }
  @{ name    =   'download_perforce_client';
      script = {
        (New-Object System.Net.WebClient).DownloadFile( "http://ftp.perforce.com/perforce/r13.2/bin.ntx64/p4.exe", "$Env:SystemRoot\System32\p4.exe" )
      };
      pre    = {
        Test-Path ("$Env:SystemDrive\System32\p4.exe")
      };
      post   = { 1 }; }
  @{ name    =   'install_iis_features';
      script = {
        Add-WindowsFeature Web-FTP-Service, Web-FTP-Ext, Web-Dir-Browsing, `
            Web-Common-HTTP, Web-Server, Web-Mgmt-Tools                    `
            -LogPath "$Env:OLLOG\Add-IISFeatures.log"
            # -IncludeManagementTools                                        `
      };
      pre    = { 1 };
      post   = { 1 }; }                                                      
  @{ name    =   'firewall_allow_remote_administration';
      script = {
        & netsh.exe firewall set service type=remoteadmin mode=enable
        & netsh.exe firewall set service RemoteAdmin enable
      };
      pre    = { 1 };
      post   = { 1 }; }                                                      
  @{ name    =   'firewall_allow_file_and_print_sharing';
      script = {
        & netsh.exe advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes
        & netsh.exe firewall set service type=fileandprint mode=enable profile=all
      };
      pre    = { 1 };
      post   = { 1 }; }                                                      
  @{ name    =   'firewall_allow_icmp_echo_requests';
      script = {
        & netsh.exe advfirewall firewall add rule name="ICMP Allow incoming V4 echo request" protocol=icmpv4:8,any dir=in action=allow
      };
      pre    = { 1 };
      post   = { 1 }; }                                                      
  @{ name    =   'firewall_allow_icmp_echo_requests';
      script = {
        & netsh.exe advfirewall firewall add rule name="ICMP Allow ICMPV4 echo request in" protocol=icmpv4:8,any dir=in action=allow
        & netsh.exe advfirewall firewall add rule name="ICMP Allow ICMPV6 echo request in" protocol=icmpv6:8,any dir=in action=allow
      };
      pre    = { 1 };
      post   = { 1 }; }                                                      
  @{ name    =   'firewall_allow_mssql';
      script = {
        netsh advfirewall firewall add rule name="SQL Server" dir=in action=allow protocol=TCP localport=1433
      };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'firewall_allow_multicast_responses';
      script = {
        & netsh.exe firewall set multicastbroadcastresponse ENABLE
      };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'firewall_allow_http';
      script = {
        netsh advfirewall firewall add rule name="HTTP" dir=in action=allow protocol=TCP localport=80
        netsh advfirewall firewall add rule name="SSL" dir=in action=allow protocol=TCP localport=443
      };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'firewall_allow_http';
      script = {
        netsh advfirewall firewall add rule name="IIS FTPSvc" action=allow service=ftpsvc protocol=TCP dir=in
        netsh advfirewall firewall add rule name="FTP Data" dir=in action=allow protocol=TCP localport=20
        netsh advfirewall firewall add rule name="FTP Ctrl" dir=in action=allow protocol=TCP localport=21
        netsh advfirewall set global StatefulFTP disable
      };
      pre    = { 1 };
      post   = { 1 }; }
),                                                                           
                                                                             
@()


# Set execution policy
# .Net 4
# Enable Firewall
# Fix Firewall Rules
# Add DNS Servers
# SQL Server 2008
# SQL Server 2008 SP2
# Add-PSSnappin XenServer
# Test Perforce Ticket
# Chrome
# Undo max windows size

# $Setup = '\\camautonfs01.eng.citrite.net\software\Microsoft\SQL\EN\2008_R2\Enterprise\Setup.exe'
# 
# & 'D:\setup.exe'                        `
#   /QS                                   `
#   /INDICATEPROGRESS                     `
#   /Action=Install                       `
#   /FEATURES=SQL,RS,CONN                 `
#   /ENU                                  `
#   /INSTANCENAME=MSSQLSERVER             `
#   /TCPENABLED=1                         `
#   /NPENABLED=1                          `
#   /SECURITYMODE=SQL                     `
#   /SQLSYSADMINACCOUNTS="BUILTIN\Administrators"  `
#   /AGTSVCACCOUNT="NT AUTHORITY\NetworkService"  `
#   /SAPWD=***REMOVED***                    `
#   /ERRORREPORTING=0                     `
#   /SQMREPORTING=0                       `
#   /SQLSVCSTARTUPTYPE=Automatic          `
#   /ISSVCStartupType=Manual              `
#   /RSSVCStartupType=Manual              `
#   /ASSVCSTARTUPTYPE=Manual              `
#   /BROWSERSVCSTARTUPTYPE=Manual         `
#   /SQLCOLLATION=Latin1_General_CI_AS    `
#   /IACCEPTSQLSERVERLICENSETERMS         `

# /PID=GYF3T-H2v88-GrPPH-HWRJP-QRTYB
# /AGTSVCPASSWORD="***REMOVED***"                    `

# /AGTSVCACCOUNT="NT AUTHORITY\Network Service"           `
# /UpdateEnabled=0                      `


#/UIMODE=AutoAdvance                  `
