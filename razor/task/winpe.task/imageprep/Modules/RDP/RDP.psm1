# Script Module RDP/RDP.psm1
#  * Renamed to avoid conflict with RemoteDesktop on Windows 8/2012

Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0


# TODO
#  * Break up security configuration into specialized functions
#  * Review registry changes


function Disable-RemoteDesktop {                #M:RemoteDesktop
  [CmdletBinding()] Param()

  Set-TerminalServicesParameter -fDenyTSConnections $True

<#
.SYNOPSIS
Disable remote desktop on the local machine.
#>
}

function Enable-RemoteDesktop {                 #M:RemoteDesktop
  [CmdletBinding()] Param(
    [ValidateRange(0,1)]
      [Int32] $UserAuthentication = 0,
    [ValidateRange(0,2)]
      [Int32] $SecurityLayer = 1,
    [Switch]  $EnableRemoteDesktopFirewallGroup = $True
  )

  Set-TerminalServicesParameter -fDenyTSConnections:$False @PSBoundParameters

<#
.SYNOPSIS
Enable remote desktop on the local machine.
#>
}

function Set-TerminalServicesParameter {
  [CmdletBinding()] Param(
    [ValidateRange(0,1)]
      [Int32] [Boolean] $fDenyTSConnections = 1,
    [ValidateRange(0,1)]
      [Int32] $UserAuthentication = 0,
    [ValidateRange(0,2)]
      [Int32] $SecurityLayer = 1,
    [ValidateRange(1,4)]
      [Int32] $MinEncryptionLevel,
    [ValidateRange(1,65535)]
      [Int32] $PortNumber,
    [Boolean] $EnableRemoteDesktopFirewallGroup = $False,
    [Boolean] $RestartTerminalServices,
    [Boolean] $Force
  )
  
  & reg.exe add "HKLM\System\CurrentControlSet\Control\Terminal Server"                     /v fDenyTSConnections /t REG_DWORD /d $fDenyTSConnections /f | Write-Verbose
  & reg.exe add "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d $UserAuthentication /f | Write-Verbose
  & reg.exe add "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v SecurityLayer      /t REG_DWORD /d $SecurityLayer      /f | Write-Verbose
  
  if ( $PortNumber ) {
    $PortNumber = [Convert]::ToString($PortNumber, 16)
    & reg.exe add "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v PortNumber       /t REG_DWORD /d $PortNumber         /f | Write-Verbose
  }

  if ( $MinEncryptionLevel ) {
    & reg.exe add "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v MinEncryptionLevel /t REG_DWORD /d $MinEncryptionLevel /f | Write-Verbose
  }

  if ( $EnableRemoteDesktopFirewallGroup ) {
    if ( (Gwmi Win32_OperatingSystem).Version -le 5.1 ) {
      & netsh.exe firewall set service RemoteDesktop enable  # legacy non-advfirewall command, required for XP/2003
    }
    else {
      & netsh.exe advfirewall firewall set rule group="remote desktop" new enable=Yes
    }
  }
  else {
    if ( (Gwmi Win32_OperatingSystem).Version -le 5.1 ) {
      & netsh.exe firewall set service RemoteDesktop disable  # legacy non-advfirewall command, required for XP/2003
    }
    else {
      & netsh.exe advfirewall firewall set rule group="remote desktop" new enable=No
    }
  }

  if ( $RestartTerminalServices ) {
    Get-Service -Name TermService | Restart-Service -Verbose:$VerbosePreference -Force:$Force
  }

<#
.SYNOPSIS
Set terminal services configuration parameters to control remote desktop access.

.PARAMETER fDenyTSConnections
fDenyTSConnections specifies whether remote desktop connections are enabled.
Reference : http://technet.microsoft.com/en-us/library/cc722151(v=ws.10).aspx

.PARAMETER UserAuthentication
When set to true, allow connections from computers running any version of remote desktop (less secure).
Reference : http://technet.microsoft.com/en-us/library/cc782610(WS.10).aspx

.PARAMETER SecurityLayer
This controls the Network Level Authentication parameters negotiated by the
client and server for the terminal services/remote desktop session.

0   Low     RDP is used by the and the client for authentication prior to
            and remote desktop prior to a remote desktop connection being established.
            Use this setting if you are working in a heterogeneous environment.

1   Medium  The server and client negotiate the method for authentication prior
            to a Remote Desktop connection being established. (This is the default value).
            Use this setting if all of your computers are running Windows.

2   High    Transport Layer Security (TLS) is used by the server anyd client for
            authentication prior to a remote desktop connection being established. 
            Use this setting for maximum security.

Reference : http://technet.microsoft.com/en-us/library/cc782610(WS.10).aspx

.PARAMETER MinEncryptionLevel
When set, this controls the encryption level to be negotiated/used for the terminal services session.

1   Low                 Data sent from the client to the server is encrypted using 56-bit encryption.
                        Data sent from the server to the client is not encrypted
2   Client Compatible   Encrypts client / server communication at the maximum key strength supported
                        by the client. Use this level when the Terminal Server is running in an 
                        environment containing mixed or legacy clients. This is the default setting.
3   High                Encrypts client/server communication using 128-bit encryption. 
                        Use this level when the clients that access the Terminal Server also support
                        128-bit encryption. If this option is set, clients that do not support 128-bit
                        encryption will not be able to connect.
4   FIPS-Compliant      All client/server communication is encrypted and decrypted with the 
                        Federal Information Processing Standard (FIPS) encryption algorithms. 
                        FIPS 140-1 (1994) and its successor, FIPS 140-2 (2001) describe these requirements

Reference : http://technet.microsoft.com/en-us/library/cc782610(WS.10).aspx

.PARAMETER PortNumber
The TCP port on which the RDP-TCP service should listen on. Default is 3389.
If the port is not the default, additional firewall configuration may be needed to allow access to the service.
#>
}

function New-RDPFile {
  [CmdletBinding()] Param (
    [Parameter(Mandatory=$True)]  [String] $HostName,
    [Parameter(Mandatory=$False)] [String] $Filename = "${Hostname}.rdp",
    [Parameter(Mandatory=$False)] [String] $Username,
    [Parameter(Mandatory=$False)] [String] $SSLCertificateSHA1Hash
  )

  if ( $Username ) {
    & reg.exe add "HKCU\Software\Microsoft\Terminal Server Client\Servers\$Hostname"  /v UsernameHint /t REG_SZ /d "$Username" /f | Write-Verbose
  }

  if ( $SSLCertificateSHA1Hash ) {
    & reg.exe add "HKCU\Software\Microsoft\Terminal Server Client\Servers\$Hostname"  /v CertHash /t REG_BINARY /d "$SSLCertificateSHA1Hash" /f | Write-Verbose
  }

$template = @"
screen mode id:i:1
use multimon:i:1
session bpp:i:16
winposstr:s:0,3,51,0,1083,716
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:2
displayconnectionbar:i:1
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:0
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:$Hostname
audiomode:i:0
redirectprinters:i:1
redirectcomports:i:0
redirectsmartcards:i:1
redirectclipboard:i:1
redirectposdevices:i:0
redirectdirectx:i:1
autoreconnection enabled:i:1
authentication level:i:2
prompt for credentials:i:0
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:1
use redirection server name:i:0
"@

  $template | Out-File -Encoding ASCII $Filename
<#
.SYNOPSIS
Generate a RDP file for use with the terminal services/remote desktop client.

.PARAMETER Hostname
Hostname (FQDN/IP Address) to connect to

.PARAMETER Filename
The filename to generate. If not supplied, the value of Hostname is used (with a .rdp suffix).

.PARAMETER Username
Username to use when connecting to the remote server.
NOTE: This is not recorded in the generated .rdp file but as a UserHint in the following registry location.
      "HKCU\Software\Microsoft\Terminal Server Client\Servers\<Hostname>\UserHint"

.PARAMETER SSLCertificateSHA1Hash
SHA1 Hash of the SSL certificate remote server.

NOTE: This is not recorded in the generated .rdp file but as a CertHash in the following registry location.
      "HKCU\Software\Microsoft\Terminal Server Client\Servers\<Hostname>\CertHash"
#>
}

function Invoke-RDP {
  [CmdletBinding()] Param(
    [String] $Filename,
    [String] $Hostname,
    [Int32]  $Port = 3389,
    [Switch] $Admin,
    [Int32]  $Width,
    [Int32]  $Height,
    [Switch] $FullScreen,
    [Switch] $Public,
    [Switch] $Span,
    [Switch] $Multimon,
    [Switch] $Edit,
    [Switch] $Migrate,
    [Switch] $Help
  )
  
  $Args = @()

  if ( $Hostname   ) { $Args+="/v:${Hostname}:${Port}" }
  if ( $Admin      ) { $Args+="/admin"      }
  if ( $FullScreen ) { $Args+="/f"          }
  if ( $Width      ) { $Args+="/w:$Width"   }
  if ( $Height     ) { $Args+="/h:$Height"  }
  if ( $Public     ) { $Args+="/public"     }
  if ( $Span       ) { $Args+="/span"       }
  if ( $MultiMon   ) { $Args+="/multimon"   }
  if ( $Migrate    ) { $Args+="/migrate"    }
  if ( $Edit       ) { $Args+="/edit"       }
  if ( $Filename   ) { $Args+="$Filename"   }
  if ( $Help       ) { $Args+="/?"          }

  Write-Verbose "& mstsc.exe $Args"
  & mstsc.exe $Args

<#
.SYNOPSIS
Start the terminal services/remote desktop client.

.DESCRIPTION
This function is a wrapper around the terminal services/remote desktop client (i.e. mstsc.exe).

Parameters are borrowed from the help of mstsc.exe (i.e. mstsc.exe /?).
#>
}
