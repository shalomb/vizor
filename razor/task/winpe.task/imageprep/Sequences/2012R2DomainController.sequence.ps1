# PowerShell.exe

Set-StrictMode  -Version  2.0
Set-PSDebug     -Trace    0

$ErrorActionPreference="STOP"

# Init - Import all modules required by tasks enclosed within.
Import-Module Microsoft.PowerShell.Host     -ea 0
Import-Module Microsoft.PowerShell.Security       


@(
  @{ name    =   'set_computer_name';
      script = { 
      # Rename-Computer -NewName dc1
      };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'convert_network_interface_to_dhcp';
      script = {
        function Get-InterfaceNameByMacAddress {
          [CmdletBinding()] Param(
            [String] $MacAddress    
          )
          Gwmi Win32_NetworkAdapter | ?{ $_.MACAddress -imatch $MacAddress } | %{ $_.NetConnectionId }
        }
  
        Gwmi Win32_NetworkAdapterConfiguration | ?{ $_.IPEnabled -and -not($_.DHCPEnabled) } | %{
          $MACAddress   = $_.MACAddress
          $InterfaceName = Get-InterfaceNameByMacAddress $MACAddress
  
          & netsh.exe interface ip set address       "$InterfaceName" dhcp
          & netsh.exe interface ip set dns      name="$InterfaceName" source=dhcp
          & netsh.exe interface ip set wins     name="$InterfaceName" source=dhcp
        }
      };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'convert_network_interface_dhcp_to_static';
      script = {
        function Get-InterfaceNameByMacAddress {
          [CmdletBinding()] Param(
            [String] $MacAddress    
          )
          Gwmi Win32_NetworkAdapter | ?{ $_.MACAddress -imatch $MacAddress } | %{ $_.NetConnectionId }
        }
  
        Gwmi Win32_NetworkAdapterConfiguration | ?{ $_.IPEnabled -and $_.DhcpEnabled } | %{
          $Interface = $_
        
          $IpAddresses  = @( $_.IPAddress             )
          $NetMasks     = @( $_.IPSubnet              )
          $IPGateways   = @( $_.DefaultIPGateway      )
          $DNSServers   = @( $_.DNSServerSearchOrder  )
          $MACAddress   = $_.MACAddress
          $DnsDomain    = $_.DnsDomain
        
          $InterfaceName = Get-InterfaceNameByMacAddress $MACAddress
        
          for ( $i=0; $i -le $IPAddresses.Count; $i++ ) {
            $IPAddress = $IPAddresses[$i]
            $NetMask   = $NetMasks[$i]
            $IPGateway = $IPGateways[$i]
            if ( -not( $IPAddress ) ) { continue }
            $Interface.EnableStatic( $IPAddress, $NetMask )
            $Interface.SetGateways( $IPGateway )
          }
        
          $Interface.SetDNSServerSearchOrder( $DNSServers )
          $Interface.SetDNSDomain( $DnsDomain )
          $Interface.SetDynamicDNSRegistration($True, $True)
        }
      };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'install_active_directory_domain_services';
    script = {
      Import-Module ServerManager
      Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
    };
    pre    = { 1 };
    post   = { 1 }; }
  @{ name    =   'set_password_required_for_administrator';
    script = { net user administrator /passwordreq:yes };
    pre    = { 1 };
    post   = { 1 }; }
  @{ name    =   'install_first_active_directory_forest';
      script = {
        Import-Module ADDSDeployment
        $SMAP = ConvertTo-SecureString $Env:SafeModeAdministratorPassword -AsPlainText -Force
        Install-ADDSForest  -DomainName $Env:DomainName `
                            -SafeModeAdministratorPassword $SMAP `
                            -NoRebootOnCompletion `
                            -Force -Verbose
      };
      pre    = { };
      post   = { 1 }; }
  @{ name    =   'set_dns_server_forwarder_addresses';
      script = { 
        $DnsServerForwarderList = ($Env:DnsServerForwarderList -join ' ') -replace ',', ' '
        dnscmd.exe 127.0.0.1 /ResetForwarders $DnsServerForwarderList /TimeOut 5 
      };
      pre    = { 1 };
      post   = { 1 }; }
),

@(
  @{ name    =   'set_dns_server_forwarder_addresses';
      script = { dnscmd.exe 127.0.0.1 /ResetForwarders 10.70.160.66 10.70.160.68 /TimeOut 5 };
      pre    = { 1 };
      post   = { 1 }; }
)


