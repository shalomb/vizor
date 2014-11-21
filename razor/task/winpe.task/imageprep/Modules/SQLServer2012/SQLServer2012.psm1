# PowerShell

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'STOP'


Function New-ConfigurationFile {

$ConfigIni = @"
; Microsoft SQL Server 2012 Configuration file
[OPTIONS]

; Specifies a Setup work flow, like INSTALL, UNINSTALL, or UPGRADE. 
; This is a required parameter. 
ACTION="Install"

; Accept the License agreement to continue with Installation
IAcceptSQLServerLicenseTerms="True"

;Set quiet mode ON, send log to command window
QUIET=True
INDICATEPROGRESS=True

; Specifies features to install, uninstall, or upgrade. 
; The lists of features include SQLEngine, FullText, Replication, 
; AS, IS, and Conn. 
FEATURES=SQLENGINE

; Specify a default or named instance. MSSQLSERVER is the default instance 
; for non-Express editions and SQLExpress for Express editions. 
; This parameter is required when installing the SQL Server Database Engine,
; and Analysis Services (AS). 
INSTANCENAME="MSSQLSERVER"

; Specify the Instance ID for the SQL Server features you have specified. 
; SQL Server directory ; structure, registry structure, and service names
; will incorporate the instance ID of the SQL Server
instance. 
INSTANCEID="MSSQLSERVER"

; Set Mixed Mode security
SECURITYMODE=SQL

; Windows account(s) to provision as SQL Server system administrators. 
; Domain/computer and account should match your environment
SQLSYSADMINACCOUNTS=

; Account for SQL Server service: Domain\User or system account. 
SQLSVCSTARTUPTYPE="Automatic"
SQLSVCACCOUNT="NT AUTHORITY\SYSTEM"
; SQLSVCPASSWORD=

; The sa (System Administrator) password
SAPWD=sqlp@55w0rd

; Make Agent Service autostart
AGTSVCSTARTUPTYPE=Automatic

; Enable TCP 
TCPENABLED=1

; Set install directories
ACTION="Install"
ADDCURRENTUSERASSQLADMIN="True" ; Provision current user as a Database Engine system administrator for SQL Server 2008 R2 Express. 
AGTSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"
AGTSVCSTARTUPTYPE="Automatic"
BROWSERSVCSTARTUPTYPE="Automatic"
ENABLERANU="True"
ENU="True"
ERRORREPORTING="False"
FARMADMINPORT="0" ; A port number used to connect to the SharePoint Central Administration web application. 
FEATURES=SQLENGINE,Conn,SSMS,ADV_SSMS ;FEATURES=SQLENGINE,FULLTEXT,SSMS,BC,Conn,ADV_SSMS
FILESTREAMLEVEL="0"
FTSVCACCOUNT="NT AUTHORITY\LOCAL SERVICE"
HELP="False"
IACCEPTSQLSERVERLICENSETERMS=1
INDICATEPROGRESS="True"
ISSVCACCOUNT="NT AUTHORITY\NetworkService"
ISSVCSTARTUPTYPE="Automatic"
; Specify 0 to disable or 1 to enable the Named Pipes protocol. 
NPENABLED="1"
QUIET="False"
QUIETSIMPLE="True"
ROLE="AllFeatures_WithDefaults"
; The default is Windows Authentication. Use "SQL" for Mixed Mode Authentication. 
SECURITYMODE="SQL"
SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS"
SQLSVCACCOUNT="NT AUTHORITY\SYSTEM"
SQLSVCSTARTUPTYPE="Automatic"
SQLTEMPDBDIR="C:\DBFiles\TempDB"
SQLTEMPDBLOGDIR="C:\DBFiles\TempDB"
SQLUSERDBDIR="C:\DBFiles\Data"
SQLUSERDBLOGDIR="C:\DBFiles\Log"
SQMREPORTING="False"
; Specify 0 to disable or 1 to enable the TCP/IP protocol. 
TCPENABLED="1"
X86="False"

; Reporting Services
RSSVCACCOUNT="NT AUTHORITY\LOCAL SERVICE"
RSSVCSTARTUPTYPE="Manual"
RSINSTALLMODE="DefaultNativeMode"
FTSVCACCOUNT="NT AUTHORITY\LOCAL SERVICE"

; The collation to be used by Analysis Services. 
ASCOLLATION="Latin1_General_CI_AS"
; The location for the Analysis Services data files. 
ASDATADIR="Data"
; The location for the Analysis Services log files. 
ASLOGDIR="Log"
; The location for the Analysis Services backup files. 
ASBACKUPDIR="Backup"
; The location for the Analysis Services temporary files. 
ASTEMPDIR="Temp"
; The location for the Analysis Services configuration files. 
ASCONFIGDIR="Config"
; Specifies whether or not the MSOLAP provider is allowed to run in process. 
ASPROVIDERMSOLAP="1"

; Agent account name 
AGTSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"

; Auto-start service after installation.  
AGTSVCSTARTUPTYPE="Automatic"
; Startup type for Integration Services. 
ISSVCSTARTUPTYPE="Automatic"
; Account for Integration Services: Domain\User or system account. 
ISSVCACCOUNT="NT AUTHORITY\NetworkService"
; Controls the service startup type setting after the service has been created. 
ASSVCSTARTUPTYPE="Automatic"
; Startup type for the SQL Server service. 
SQLSVCSTARTUPTYPE="Automatic"
; Account for SQL Server service: Domain\User or system account. 
SQLSVCACCOUNT="NT AUTHORITY\SYSTEM"
; Startup type for Browser Service. 
BROWSERSVCSTARTUPTYPE="Automatic"

; Specify the root installation directory for native shared components. 
INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server"
; Specify the SQL program installation directory. 
INSTANCEDIR="C:\Program Files\Microsoft SQL Server"
; Specify that SQL Server feature usage data can be collected and sent to Microsoft. Specify 1 or True to enable and 0 or False to disable this feature. 
SQMREPORTING="True"
; Specify a default or named instance. MSSQLSERVER is the default instance for non-Express editions and SQLExpress for Express editions. This parameter is required when installing the SQL Server Database Engine
(SQL), Analysis Services (AS), or Reporting Services (RS). 
INSTANCENAME="TOTALFBO"
; Specify the user database directory location
SQLUSERDBDIR="C:\Program Files\Microsoft SQL Server\MSSQL10_50.TOTALFBO\MSSQL\Data"
; Specify the user database log directory location
SQLUSERDBLOGDIR="C:\Program Files\Microsoft SQL Server\MSSQL10_50.TOTALFBO\MSSQL\Data"
;Specify the database backup directory location
SQLBACKUPDIR="C:\Program Files\Microsoft SQL Server\MSSQL10_50.TOTALFBO\MSSQL\Backup"
"@

$ConfigIni
}
