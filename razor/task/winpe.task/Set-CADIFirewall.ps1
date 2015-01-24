<#
.SYNOPSIS
   Script sets firewall for inbound CADI bootstrap.

   Copyright (c) 2014 Automation, Citrix Systems UK Ltd.

.DESCRIPTION
   Set inbound firewall rules to enable CADI to be installed
   via PSEXEC call
#>

$ports = @{}
$ports.Add(135, "***AUTOMATION Open Port 135 For CADI bootstrap***")
$ports.Add(445, "***AUTOMATION Open Port 445 For CADI bootstrap***")
#

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
    Write-Host "Set Firewall Rules - Port=$_ Name=""$($ports[$_])""" 
    netsh.exe advfirewall firewall add rule name=$($ports[$_]) `
       protocol=TCP localport=$_ dir=in action=allow profile=any enable=yes
    netsh.exe advfirewall firewall show rule name=$($ports[$_]) 
  }

  Write-Host "Setting Firewall Rules - ICMPv4 Echo Request/Reply"
  netsh.exe advfirewall firewall add rule name="Allow ICMPv4 Echo Request In" `
      protocol=icmpv4:8,any dir=in  action=allow profile=any enable=yes
  netsh.exe advfirewall firewall add rule name="Allow ICMPv4 Echo Reply Out" `
      protocol=icmpv4:0,any dir=out action=allow profile=any enable=yes

  Write-Host "Setting Firewall Rules - ICMPv6 Echo Request/Reply"
  netsh.exe advfirewall firewall add rule name="Allow ICMPv6 Echo Request In" `
      protocol=icmpv6:128,any dir=in  action=allow profile=any enable=yes
  netsh.exe advfirewall firewall add rule name="Allow ICMPv6 Echo Reply Out" `
      protocol=icmpv6:129,any dir=out action=allow profile=any enable=yes

  # Start Remote Registry
  if ( Get-Service RemoteRegistry ) {
    # WORKAROUND, RemoteRegistry is reported to not start occasionally
    while ( (Get-Service RemoteRegistry).Status -ne 'Running' ) {
      Get-Service RemoteRegistry |
        Set-Service -StartupType Automatic -Verbose -PassThru |
        Restart-Service -Verbose -Force -PassThru
      sleep 1
    }
  }
}

