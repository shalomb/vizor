# PowerShell

Set-StrictMode -Version 2
$ErrorActionPreference="STOP"
Set-PSDebug -Trace 0

Import-Module RDP             -Verbose:$VerbosePreference
Import-Module ServerManager   -Verbose:$VerbosePreference

# Stage 0
@(
  @{ name    =   'install_dotnet3.5_prereq_for_sql_server_2012';
      script = {
        dism.exe  /enable-feature       `
                  /feature-name:netfx3  `
                  /all                  `
                  /limitaccess          `
                  /source:$Env:SxsSourcePath
      };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'install_sql_server_2012_r2_sp1';
      script = {
        $cmd = "{0}"                                  `
                /QS                                   `
                /INDICATEPROGRESS                     `
                /Action=Install                       `
                /FEATURES=SQLEngine,SQL,RS,CONN       `
                /ENU                                  `
                /INSTANCENAME=MSSQLSERVER             `
                /TCPENABLED=1                         `
                /NPENABLED=1                          `
                /SECURITYMODE=SQL                     `
                /SQLSYSADMINACCOUNTS="BUILTIN\Administrators"  `
                /AGTSVCACCOUNT="NT AUTHORITY\NetworkService"  `
                /SAPWD=***REMOVED***                    `
                /ERRORREPORTING=0                     `
                /SQMREPORTING=0                       `
                /SQLSVCSTARTUPTYPE=Automatic          `
                /ISSVCStartupType=Manual              `
                /RSSVCStartupType=Manual              `
                /ASSVCSTARTUPTYPE=Manual              `
                /BROWSERSVCSTARTUPTYPE=Manual         `
                /SQLCOLLATION=Latin1_General_CI_AS    `
                /IACCEPTSQLSERVERLICENSETERMS         `
                /UpdateEnabled=True                   `
                /ADDCURRENTUSERASSQLADMIN=True        `
                /HIDECONSOLE=False                    `
                -f $Env:SQLServerSetup
        Write-Host -Fore Cyan "$cmd"
      };
      pre    = { 1 };
      post   = { 1 }; }
),

@()

