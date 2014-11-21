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
if([Environment]::OSVersion.Version.Major -lt 6)
{
	$ports.Keys | % { netsh firewall add portopening TCP $_ $( $ports[$_]) }
	netsh firewall show portopening 
}
else
{
	$ports.Keys | % { Write-Host "Set Firewall Rules Port=$_ Name=""$($ports[$_])""" }
	$ports.Keys | % { netsh advfirewall firewall add rule name=$($ports[$_]) dir=in action=allow protocol=TCP localport=$_ }
	$ports.Keys | % { netsh advfirewall firewall show rule name=$($ports[$_]) }
}