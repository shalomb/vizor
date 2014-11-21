# PowerShell

Set-StrictMode -Version 2.0
$ErrorActionPreference = "STOP"

function Get-AdvFirewallRule {
  [CmdLetBinding()]
  Param(
    [String] $Name,
    [String] $Protocol,
    [String] $Action,
    [String] $FullName,
    [String] $Profile,
    [String] $Type,
    [Switch] $Extended
  )

  $NetshArgs = @()
  if ( $FullName  )   { $NetshArgs += @( "name=$FullName"   ) }
                else  { $NetshArgs += @( "name=ALL"         ) }
  if ( $Profile   )   { $NetshArgs += @( "profile=$Profile" ) }
  if ( $Type      )   { $NetshArgs += @( "type=$Type"       ) }
  if ( $Extended  )   { $NetshArgs += @( "verbose"          ) }

  $NetshCmd = "netsh.exe advfirewall firewall show rule $NetshArgs"

  if ( $Name ) {
    Get-AdvFirewallRule | ?{ $_.RuleName -imatch $Name }
  }
  else {
    $Rule = New-Object PSObject
    $LastKey = $Null
    Write-Verbose "netsh cmd : $NetshCmd"
    $Stdout = iex $NetshCmd 
    $Stdout | %{
      if ( $_ -imatch "^\s*$" ) {
        if ( $Rule | gm -MemberType NoteProperty ) { # Object is defined.
          Write-Output $Rule
        }
        $Rule = New-Object PSObject
      } 
      elseif ( $_ -imatch ":" ) {
        ([String]$Key, $Value) = ([Regex]::Match($_, "^([^:]+)\s*:\s*(.+)$")).Groups[1,2]
        $Key = $Key -replace "[\t\s\ ]+",""
        $LastKey = $Key
        if ( ([String]$Key) -imatch 'Profiles|(Local|Remote)Port|IP|InterfaceTypes' ) { 
          [String[]]$Value = $Value -split ',' 
        }
        else {
          [String]$Value = $Value
        }
        $Rule = $Rule | Add-Member NoteProperty $Key $Value -PassThru
      }
      elseif ( $_ -imatch "^\s+(Type)\s+(Code)\s*$" ) {
        $TypeCodeKeys = ([Regex]::Match($_, "^\s+(\S+)\s+(\S+)\s*$")).Groups[1,2]
      }
      elseif ( $_ -imatch "^\s+(\S+)\s+(\S+)\s*$" ) {
        $TypeCodeVals = ([Regex]::Match($_, "^\s+(\S+)\s+(\S+)\s*$")).Groups[1,2]
        0..1 | %{
          $k = $TypeCodeKeys[$_] 
          $v = $TypeCodeVals[$_]
          $Rule | Add-Member NoteProperty "$LastKey$k" $v
        }
      }
      elseif ( $_ -imatch "^(\-*|OK.)$" ) {
        ;
      } 
      else {
        Write-Warning "$LastKey [$_]"
        throw $_
      }
    }
  }
}

function Get-AdvFirewallProfile {
  [CmdLetBinding()]
  Param(
    [Switch]$Public,
    [Switch]$Domain,
    [Switch]$Curent,
    [Switch]$Private,
    [Switch]$All,
    [Switch]$Global = $True
  )

  $Profile = 'all'
  $Profile =      if ( $Public  )  { 'public' }
              elseif ( $Domain  )  { 'domain' }
              elseif ( $Curent  )  { 'current' }
              elseif ( $Private )  { 'private' }
              elseif ( $Global  )  { 'global' }
              elseif ( $Global  )  { 'all' }

  netsh.exe advfirewall show $Profile | % -begin { 
    $Rule = New-Object PSObject 
  } -process {
    if ( $_ -imatch "\S\s\s+\S" ) {
      ([String]$Key, [String]$Value)=([Regex]::Match($_, "^(.*\S+)\s\s+(\S+.*)$")).Groups[1,2]
      $Key = $Key -replace " ",""
      if ( $Value -imatch ',' ) { [String[]]$Value = $Value -split ',' }
      $Rule = $Rule | Add-Member NoteProperty $Key $Value -PassThru
    } 
  } -end { Write-Output $Rule }
}

function New-AdvFirewallPortRule {
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory=$True)] [String] $Name,
    [Parameter(Mandatory=$True)] [String] $Profile,
    [ValidateSet("in", "out")] 
      [String] $Direction  = "in",
    [String] $LocalPort = "Any",  # Need to accommodate ranges as well e.g. 1024-655535
    [String] $RemotePort = "Any",  # Need to accommodate ranges as well e.g. 1024-655535
    [ValidateSet("TCP", "UDP", "Any", "icmpv4", "icmpv6", "icmpv4:code",
      "icmpv4:type", "icmpv6:type", "icmpv6:code")] 
      [String] $Protocol   = "Any",
    [ValidateSet("allow", "block", "bypass")] 
      [Switch] $Action     = "allow",
    [String[]] $LocalIP,
    [String[]] $RemoteIP
  )
  $CmdArgs = @()
  
  if ( $RemoteIP ) { $CmdArgs += ( "remoteip=$($RemoteIP -join ',')" ) }
  if ( $LocalIP  ) { $CmdArgs += ( "localip=$($LocalIP   -join ',')"   ) }

  & netsh.exe advfirewall firewall add rule `
    name=$Name dir=$Direction action=$Action protocol=$Protocol `
    localport=$LocalPort remoteport=$RemotePort `
    profile=$Profile $CmdArgs
}

function New-AdvFirewallProgramRule {
  [CmdLetBinding()]
  Param(
    [String] $Name,
    [String] $Path,
    [ValidateSet("in", "out")] 
      [String] $Direction  = "in",
    [ValidateSet("allow", "block", "bypass")] 
      [Switch] $Action     = "allow",
    [ValidateSet("Yes", "No")] 
      [Switch] $Enable = "Yes"
  )
  $CmdArgs = @()

  if ( $RemoteIP ) { $CmdArgs += ( "remoteip=$($RemoteIP -join ',')" ) }
  if ( $LocalIP  ) { $CmdArgs += ( "localip=$($LocalIP   -join ',')"   ) }

  & netsh.exe advfirewall firewall add rule `
    name=$Name dir=$Direction action=$Action program=$Path `
    $CmdArgs
}

function Set-AdvFirewallLogging {
  [CmdLetBinding()]
  Param(
    [String] $Filename,
    [Int32]  $MaxFileSize,
    [Switch] $DroppedConnections,
    [Switch] $AllowedConnections,
    [ValidateSet('domainprofile', 'publicprofile', 'privateprofile', 'allprofiles')] 
      [String] $Profile = 'currentprofile'
  )
  
  if ( $Filename ) {
    & netsh.exe advfirewall firewall $Profile logging filename="$Filename" 
  }

  if ( $MaxFileSize ) {
    & netsh.exe advfirewall firewall $Profile logging maxfilesize $MaxFileSize
  } 

  if ( $DroppedConnections -ne $Null ) {
    $Action = if ( $DroppedConnections ) { "enable" } else { "disable" }
    & netsh.exe advfirewall firewall $Profile logging droppedconnections $Action
  }

  if ( $AllowedConnections -ne $Null ) {
    $Action = if ( $AllowedConnections ) { "enable" } else { "disable" }
    & netsh.exe advfirewall firewall $Profile logging allowedconnections $Action
  }
}

function Get-AdvFirewallGroup {
  [CmdLetBinding()] Param()
  Get-AdvFirewallRule | %{ $_.Grouping } | sort -Unique

<#
.SYNOPSIS
List the various Firewall Groups

#>
}

function Set-AdvFirewallGroupState {
  [CmdLetBinding()] Param(
    [String] $Group,
    [Switch] $Disabled
  )
  $AdvFirewallGroupState = 'yes'
  if ( $Disabled -ne $Null ) { $AdvFirewallGroupState = if ( $Disabled ) { 'no' } else { 'yes' } }
  Write-Verbose "& netsh.exe advfirewall firewall set rule group='$Group' new enable=$AdvFirewallGroupState"
  & netsh.exe advfirewall firewall set rule group="$Group" new enable=$AdvFirewallGroupState
}

function Enable-AdvFirewallGroup {
  [CmdLetBinding()] Param(
    [String]$Group
  )
  Set-AdvFirewallGroupState -Group $Group
}

function Disable-AdvFirewallGroup {
  [CmdLetBinding()] Param(
    [String]$Group
  )
  Set-AdvFirewallGroupState -Group $Group -Disabled
}

function Set-AdvFirewallState {
  [CmdLetBinding()]
  Param(
    [ValidateSet('domainprofile', 'publicprofile', 'privateprofile', 'allprofiles')] 
      [String] $Profile = 'allprofiles',
    [Switch] $Disabled
  )
  $AdvFirewallState = 'on'
  if ( $AdvFirewallState -ne $Null ) { $AdvFirewallState = if ( $Disabled ) { 'off' } else { 'on' } }
  & netsh.exe advfirewall set $Profile state $AdvFirewallState
}

function Disable-AdvFirewall {
  [CmdLetBinding()] Param()
  Set-AdvFirewallState -Disabled:$True
}

function Enable-AdvFirewall {
  [CmdLetBinding()] Param()
  Set-AdvFirewallState -Disabled:$False
}

function Set-AdvFirewallIcmpPolicy {
  [CmdLetBinding()] Param(
    [ValidateSet('v4','v6','both')]
      [String] $IPVersion = 'both',
    [ValidateSet('allow','deny')]
      [String] $Action,
    [ValidateSet('in','out')]
      [String] $Direction,
    [Switch] $Disabled = $False
  )

  $RulesToEffect = @()
  $IcmpVersion   = @()
  if ( $IPVersion -imatch 'v4' ) {
    $RulesToEffect += @('All ICMP V4', 'All ICMP V6')
    $IcmpVersion += @( 'icmpv4', 'icmpv6' )
  }
  elseif ( $IPVersion -imatch 'v4' ) {
    $RulesToEffect += @( 'All ICMP V4' )
    $IcmpVersion += @( 'icmpv4' )
  }
  elseif ( $IPVersion -imatch 'v6|both' ) {
    $RulesToEffect += @( 'All ICMP V6' )
    $IcmpVersion += @( 'icmpv6' )
  }
  
  $AdvFirewallIcmpv4Action = 'allow'
  if ( $AdvFirewallIcmpv4Action -ne $Null ) { $AdvFirewallIcmpv4Action = if ( $Disabled ) { 'block' } else { 'allow' } }

  # TODO, protocol needs to match RuleName
  $RulesToEffect | %{
    & netsh.exe advfirewall firewall add rule name="$_" dir=$Direction action=$AdvFirewallIcmpv4Action protocol=$IcmpVersion,any,any
  }
}

function Set-AdvFirewallIcmpv4 {
  [CmdLetBinding()] Param(
    [Switch] $Disabled = $False
  )
  $AdvFirewallIcmpv4Action = 'allow'
  if ( $AdvFirewallIcmpv4Action -ne $Null ) { $AdvFirewallIcmpv4Action = if ( $Disabled ) { 'block' } else { 'allow' } }
  & netsh.exe advfirewall firewall add rule name='All ICMP V4' dir=in action=$AdvFirewallIcmpv4Action protocol=icmpv4,any,any
}

function Enable-AdvFirewallIcmpv4 {
  [CmdLetBinding()] Param()
  Set-AdvFirewallIcmpv4 -Disabled:$False
}

function Disable-AdvFirewallIcmpv4 {
  [CmdLetBinding()] Param()
  Set-AdvFirewallIcmpv4 -Disabled:$True
}

function Set-AdvFirewallIcmpv6 {
  [CmdLetBinding()] Param(
    [Switch] $Disabled = $False
  )
  $AdvFirewallIcmpv6Action = 'allow'
  if ( $AdvFirewallIcmpv6Action -ne $Null ) { $AdvFirewallIcmpv6Action = if ( $Disabled ) { 'block' } else { 'allow' } }
  & netsh.exe advfirewall firewall add rule name='All ICMP V6' dir=in action=$AdvFirewallIcmpv6Action protocol=icmpv6,any,any
}

function Enable-AdvFirewallIcmpv6 {
  [CmdLetBinding()] Param()
  Set-AdvFirewallIcmpv6 -Disabled:$False
}

function Disable-AdvFirewallIcmpv6 {
  [CmdLetBinding()] Param()
  Set-AdvFirewallIcmpv6 -Disabled:$True
}

function Repair-AdvFirewall {
  [CmdLetBinding()]
  Param()
  & netsh.exe advfirewall reset
<#
Reset the advfirewall state back to the default.
#>
}

function Import-AdvFirewallSettings {
  [CmdLetBinding()] Param (
    [Parameter(Mandatory=$True)] [String] $Filename
  )
  & netsh.exe advfirewall import "$Filename"
}

function Export-AdvFirewallSettings {
  [CmdLetBinding()] Param (
    [Parameter(Mandatory=$True)] [String] $Filename
  )
  & netsh.exe advfirewall export "$Filename"
}

