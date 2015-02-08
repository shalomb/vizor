<#
.SYNOPSIS
Script to set up firewall and services for CADI bootstrap.

Copyright (c) 2014 Automation, Citrix Systems UK Ltd.

.DESCRIPTION
Set inbound firewall rules to
  * Allow TCP ports 135 and 445 inbound (for PSExec)
  * Allow ICMP Echo Request/Reply
Start the following services
  * Remote Registry
#>

$ports = @{
   '135' = '***AUTOMATION Opening Port 135 (EPMAP/RPC) for CADI bootstrap***';
   '139' = '***AUTOMATION Opening Port 139 (NetBIOS Session Service) for CADI bootstrap***';
   '145' = '***AUTOMATION Opening Port 145 () for CADI bootstrap***';
   '445' = '***AUTOMATION Opening Port 445 (Microsoft SMB/DS) for CADI bootstrap***';
  '7999' = '***AUTOMATION Opening Port 7999 for CADI bootstrap***';
  '8000' = '***AUTOMATION Opening Port 8000 for CADI bootstrap***';
}

$ServicesToStart = @('RemoteRegistry', 'NetTcpPortSharing')

# If on winxp use  netsh firewall
if([Environment]::OSVersion.Version.Major -lt 6) {
  $ports.Keys | % {
    netsh.exe firewall add portopening TCP $_ $( $ports[$_]) 
  }
  netsh.exe firewall show portopening

  netsh.exe firewall set icmpsetting 8 enable
} else {
  netsh.exe advfirewall reset

  $ports.Keys | % {
    Write-Host "Set Firewall Rules - Port=$_ Name='$($ports[$_])'" 
    netsh.exe advfirewall firewall add rule name=$($ports[$_]) `
       protocol=TCP localport=$_ dir=in action=allow profile=any enable=yes
    netsh.exe advfirewall firewall show rule name=$($ports[$_]) 
  }

  Write-Host 'Setting Firewall Rules - ICMPv4 Echo Request/Reply'
  netsh.exe advfirewall firewall add rule name='Allow ICMPv4 Echo Request In' `
      protocol='icmpv4:8,any' dir=in  action=allow profile=any enable=yes
  netsh.exe advfirewall firewall show rule name='Allow ICMPv4 Echo Request In'

  netsh.exe advfirewall firewall add rule name='Allow ICMPv4 Echo Reply Out' `
      protocol='icmpv4:0,any' dir=out action=allow profile=any enable=yes
  netsh.exe advfirewall firewall show rule name='Allow ICMPv4 Echo Reply Out'

  Write-Host 'Setting Firewall Rules - ICMPv6 Echo Request/Reply'
  netsh.exe advfirewall firewall add rule name='Allow ICMPv6 Echo Request In' `
      protocol='icmpv6:128,any' dir=in  action=allow profile=any enable=yes
  netsh.exe advfirewall firewall show rule name='Allow ICMPv6 Echo Request In'

  netsh.exe advfirewall firewall add rule name='Allow ICMPv6 Echo Reply Out' `
      protocol='icmpv6:129,any' dir=out action=allow profile=any enable=yes
  netsh.exe advfirewall firewall show rule name='Allow ICMPv6 Echo Reply Out'

}

foreach ( $Service in $ServicesToStart ) {
  if ( Get-Service $Service ) {
    Write-Host "Starting service '$Service' for CADI"
    while ( (Get-Service $Service).Status -ne 'Running' ) {
      Get-Service $Service |
      Set-Service -StartupType Automatic -Verbose -PassThru |
      Restart-Service -Verbose -Force -PassThru
      sleep 1
    }
  }
  else {
    Write-Warning "Error, service '$Service' not found while attempting to start it."
  }
}


