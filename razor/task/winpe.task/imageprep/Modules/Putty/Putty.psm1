#!Powershell


Set-StrictMode -version 2.0
$ErrorActionPreference = "STOP"

$PuttySuite  = @('putty.exe','puttytel.exe','pscp.exe','psftp.exe','plink.exe','pageant.exe','puttygen.exe')
$PuttyExtras = @('../md5sums', '../md5sums.RSA', '../sha1sums', '../sha1sums.RSA', '../sha512sums', '../sha512sums.RSA','../puttydoc.txt')
$Available   = @()
$ToInstall   = @()
$PuttyBasePath = Join-Path (${Env:PROGRAMFILES(x86)}, $Env:PROGRAMFILES -ne $Null)[0] 'Putty'
$PuttyRegKey   = 'HKCU:\Software\SimonTatham\PuTTY'

# Check we have all the tools necessary for this module.
$Available = $PuttySuite | %{
  if ( $Candidate = Get-ItemProperty $PuttyRegKey -Name $_ -ea 0 | Select -ExpandProperty $_ ) {
    $Candidate  = ([System.IO.FileInfo]$Candidate)
    $Path       = $Candidate.Directory
    $Name       = $Candidate.Name
    if ( ($Env:PATH -split ';') -notcontains $Path ) {
      $Env:PATH = "$Path;$Env:PATH"
    }
    return $Name
  }
}

if ( $Unavailable = $PuttySuite | ?{ $Available -notcontains $_ } ) {
  Get-Command $Unavailable -ea 0 | Sort -Unique | %{
    $Available += $_.Name
  }
  $ToInstall = $PuttySuite | ?{ $Available -NotContains $_ }
}

if ( ($Env:PATH -split ';') -notcontains $PuttyBasePath ) {
  $Env:PATH = "$PuttyBasePath;$Env:PATH"
}


function Invoke-PuTTY {
  [CmdletBinding()] Param(
                        [String] $Hostname,
                        [String] $Command, # Plink
    [Alias("load")]     [String] $Session,
    [Alias("l")]        [String] $User,
    [Alias("pw")]       [String] $Password,
    [Alias("m")]        [String] $CommandScript,
    [Alias("i")]        [String] $PrivateKeyFile,
    [Alias("ac")]       [Switch] $AutoAcceptHostKey,
    [Alias("P")]        [String] $Port,
    [Alias("pgpfp")]    [Switch] $PGPFingerPrint,
                        [Switch] $SSH,
                        [Switch] $Telnet,
                        [Switch] $RLogin,
                        [Switch] $Raw,
                        [Switch] $Serial, # PuTTY
    [Alias("1")]        [Switch] $SSHv1,
    [Alias("2")]        [Switch] $SSHv2,
    [Alias("4")]        [Switch] $IPv4,
    [Alias("6")]        [Switch] $IPv6,
                        [Switch] $Batch,
                        [Switch] $Cleanup, # PuTTY
    [Alias("sercfg")]   [String] $SerialPortConfiguration, # PuTTY
    [Alias("loghost")]  [String] $LogicalHost, # PuTTY
    [Alias("spf")]      [String] $SOCKSPortForwardConfiguration,
    [Alias("lpf")]      [String] $LocalPortForwardConfiguration,
    [Alias("rpf")]      [String] $RemotePortForwardConfiguration,
    [Alias("X")]        [Switch] $EnableX11Forwarding,
    [Alias("noX")]      [Switch] $DisableX11Forwarding,
    [Alias("A")]        [Switch] $EnableAgentForwarding,
    [Alias("noA")]      [Switch] $DisableAgentForwarding,
    [Alias("t")]        [Switch] $EnablePTYAllocation,
    [Alias("noT")]      [Switch] $DisablePTYAllocation,
    [Alias("C")]        [Switch] $EnableCompression,
    [Alias("noagent")]  [Switch] $DisableAgent,
    [Alias("agent")]    [Switch] $EnableAgent,
    [Alias("N")]        [Switch] $NoShell,
    [Alias("nc")]       [String] $TunnelConfiguration,
    [Alias("V")]        [Switch] $DisplayVersion
  )

  if ( $VerbosePreference -eq 'Continue' ) { $Args += @('-v') }
  if ( $Session                   ) { $Args += @( '-load',$Session        ) }
  if ( $User                      ) { $Args += @( '-l',   $User           ) }
  if ( $Password                  ) { $Args += @( '-pw',  $Password       ) }
  if ( $Port                      ) { $Args += @( '-P',   $Port           ) }
  if ( $PrivateKeyFile            ) { $Args += @( '-i',   $PrivateKeyFile ) }
  if ( $CommandScript             ) { $Args += @( '-m',   $CommandScript  ) }
  if ( $TunnelConfiguration             ) { $Args += @( '-nc',  $TunnelConfiguration            ) }
  if ( $SOCKSPortForwardConfiguration   ) { $Args += @( '-D',   $SOCKSPortForwardConfiguration  ) }
  if ( $LocalPortForwardConfiguration   ) { $Args += @( '-L',   $LocalPortForwardConfiguration  ) }
  if ( $RemotePortForwardConfiguration  ) { $Args += @( '-R',   $RemotePortForwardConfiguration ) }
  if ( $SerialPortConfiguration         ) { $Args += @( '-sercfg',  $SerialPortConfiguration    ) }  #p
  if ( $LogicalHost                     ) { $Args += @( '-loghost', $LogicalHost                ) }  #p
  if ( $SSHv1                     ) { $Args += @( '-1'  ) }
  if ( $SSHv2                     ) { $Args += @( '-2'  ) }
  if ( $IPv4                      ) { $Args += @( '-4'  ) }
  if ( $IPv6                      ) { $Args += @( '-6'  ) }
  if ( $EnableX11Forwarding       ) { $Args += @( '-X'  ) }
  if ( $DisableX11Forwarding      ) { $Args += @( '-x'  ) }
  if ( $EnableAgentForwarding     ) { $Args += @( '-A'  ) }
  if ( $DisableAgentForwarding    ) { $Args += @( '-a'  ) }
  if ( $EnablePTYAllocation       ) { $Args += @( '-t'  ) }
  if ( $DisablePTYAllocation      ) { $Args += @( '-t'  ) }
  if ( $EnableCompression         ) { $Args += @( '-C'  ) }
  if ( $NoShell                   ) { $Args += @( '-N'  ) }
  if ( $DisplayVersion            ) { $Args += @( '-V'  ) }
  if ( $SSH                       ) { $Args += @( '-ssh'      ) }
  if ( $Telnet                    ) { $Args += @( '-telnet'   ) }
  if ( $RLogin                    ) { $Args += @( '-rlogin'   ) }
  if ( $Raw                       ) { $Args += @( '-raw'      ) }
  if ( $Serial                    ) { $Args += @( '-serial'   ) } #p
  if ( $DisableAgent              ) { $Args += @( '-noagent'  ) }
  if ( $Batch                     ) { $Args += @( '-batch'    ) }
  if ( $Cleanup                   ) { $Args += @( '-cleanup'  ) } #p
  if ( $EnableAgent               ) { $Args += @( '-agent'    ) }
  if ( $PGPFingerPrint            ) { $Args += @( '-pgpfp'    ) }
  if ( $Hostname                  ) { $Args += @( $Hostname   ) }
  if ( $Command                   ) { $Args += @( $Command    ) }

  if ( $Args ) {
    Write-Verbose "& PuTTY.exe $Args"
    & PuTTY.exe $Args
  }
  else {
    Write-Verbose "& PuTTY.exe"
    & PuTTY.exe
  }

<#
.SYNOPSIS
Invoke PuTTY to create a SSH/Telnet/Rlink/Raw/Serial connection to a remote host.

.DESCRIPTION
PuTTY is an SSH/Telnet/Rlink/Raw/Serial client and Terminal Emulator

This function serves as a wrapper around the PuTTY.exe command line utility,
taking the parameters passed and creating a PuTTY command line that is then
executed to launch a PuTTY session.

The documentation of parameters to PuTTY tools are copied verbatim from the
PuTTY manual. For the authoritative documentation, refer to Chapter 3
(Using PuTTY) of the PuTTY documentation.
Also see RELATED LINKS below.

.EXAMPLE
Invoke-PuTTY -HostName host.example.com -UserName root
# Start a PuTTY ssh against a host named host.example.com

.EXAMPLE
Invoke-PuTTY -HostName host.example.com -UserName root -Telnet
# Start a PuTTY telnet against a host named host.example.com

.EXAMPLE
Invoke-PuTTY -Load session-foo
# Invoke PuTTY against a saved-PuTTY session named session-foo
#  See New-PuTTYSession for creating sessions

.LINK
PuTTY User Manual          - http://the.earth.li/~sgtatham/putty/0.63/htmldoc/

.LINK
Chapter 3: Using PuTTY     - http://the.earth.li/~sgtatham/putty/0.63/htmldoc/Chapter3.html

.LINK
3.8 The PuTTY command line - http://the.earth.li/~sgtatham/putty/0.63/htmldoc/Chapter3.html#using-cmdline

.PARAMETER Hostname
Host (DNS Name/FQDN/IP Address/Saved Session name) of the form [user@]host.@@@@

.PARAMETER Session
-load  Session as required by (see New-PuTTYSession/Get-PuTTYSession)

.PARAMETER User
-l user  Connect with the specified username.

.PARAMETER Password
-pw passw  Login with the specified password. SSH only.

.PARAMETER Command
Command to execute on the remote host.

.PARAMETER Port
-P  Port to connect to, the port is dependent on the protocol used (SSH, telnet, rlogin, etc).

.PARAMETER Protocol
-ssh, -telnet, -rlogin, -raw  Force use of a particular protocol.

.PARAMETER AutoAcceptHostKey
Kludge to accept the host key of the remote SSH host - required for automation.
DO NOT EMPLOY THIS IN PRODUCTION SYSTEM, for details please refer to the advice in
'PuTTY wish accept-host-keys'
http://www.chiark.greenend.org.uk/~sgtatham/putty/wishlist/accept-host-keys.html

.PARAMETER CommandScript
-m  Read remote commands from file. SSH only.

.PARAMETER PrivateKeyFile
-i  Private key file (*.ppk) for authentication. SSH only.

.PARAMETER PGPFingerPrint
-pgpfp  Print PGP key fingerprints and exit.

.PARAMETER Batch
-batch  Disable all interactive prompts.

.PARAMETER SOCKSPortForwardConfiguration
-D [listen-IP:]listen-port  Dynamic SOCKS-based port forwarding. SSH only.

.PARAMETER LocalPortForwardConfiguration
-L [listen-IP:]listen-port:host:port  Forward local port to remote address. SSH only.

.PARAMETER RemotePortForwardConfiguration
-R [listen-IP:]listen-port:host:port  Forward remote port to local address. SSH only.

.PARAMETER EnableX11Forwarding
-X  Enable X11 forwarding. SSH only.

.PARAMETER DisableX11Forwarding
-x  Disable X11 forwarding. SSH only.

.PARAMETER EnableAgentForwarding
-A  Enable agent (Pageant) forwarding. SSH only.

.PARAMETER DisableAgentForwarding
-a  Disable agent (Pageant) fowarding. SSH only.

.PARAMETER EnablePTYAllocation
-t  Enable pty allocation. SSH only.

.PARAMETER DisablePTYAllocation
-T  Disable pty allocation. SSH only.

.PARAMETER SSHv1
-1  Force use of SSH protocol version 1. SSH only.

.PARAMETER SSHv2
-2  Force use of SSH protocol version 2. SSH only.

.PARAMETER IPv4
-4  Force use of IPv4. SSH Only.

.PARAMETER IPv6
-6  Force use of IPv6. SSH Only.

.PARAMETER EnableCompression
-C  Enable Compression. SSH only.

.PARAMETER DisableAgent
-noagent  Disable use of Pageant. SSH only.

.PARAMETER EnableAgent
-agent  Enable use of Pageant. SSH only.

.PARAMETER NoShell
-N  Do not start a shell/command. SSH-2 only.

.PARAMETER TunnelConfiguration
-nc host:port  Open a tunnel in place of a session. SSH-2 only.
#>
}

Set-Alias PuTTY Invoke-PuTTY

function Invoke-Plink {
  [CmdletBinding()] Param(
                        [String] $Hostname,
                        [String] $Command, # Plink
    [Alias("load")]     [String] $Session,
    [Alias("l")]        [String] $User,
    [Alias("pw")]       [String] $Password,
    [Alias("m")]        [String] $CommandScript,
    [Alias("i")]        [String] $PrivateKeyFile,
    [Alias("ac")]       [Switch] $AutoAcceptHostKey,
    [Alias("P")]        [String] $Port,
    [Alias("pgpfp")]    [Switch] $PGPFingerPrint,
                        [Switch] $SSH,
                        [Switch] $Telnet,
                        [Switch] $RLogin,
                        [Switch] $Raw,
    [Alias("1")]        [Switch] $SSHv1,
    [Alias("2")]        [Switch] $SSHv2,
    [Alias("4")]        [Switch] $IPv4,
    [Alias("6")]        [Switch] $IPv6,
                        [Switch] $Batch,
    [Alias("spf")]      [String] $SOCKSPortForwardConfiguration,
    [Alias("lpf")]      [String] $LocalPortForwardConfiguration,
    [Alias("rpf")]      [String] $RemotePortForwardConfiguration,
    [Alias("X")]        [Switch] $EnableX11Forwarding,
    [Alias("noX")]      [Switch] $DisableX11Forwarding,
    [Alias("A")]        [Switch] $EnableAgentForwarding,
    [Alias("noA")]      [Switch] $DisableAgentForwarding,
    [Alias("t")]        [Switch] $EnablePTYAllocation,
    [Alias("noT")]      [Switch] $DisablePTYAllocation,
    [Alias("C")]        [Switch] $EnableCompression,
    [Alias("noagent")]  [Switch] $DisableAgent,
    [Alias("agent")]    [Switch] $EnableAgent,
    [Alias("s")]        [Switch] $SSH2SubSystem, # Plink
    [Alias("N")]        [Switch] $NoShell,
    [Alias("nc")]       [String] $TunnelConfiguration,
    [Alias("V")]        [Switch] $DisplayVersion,
    [Parameter(
      Mandatory=$False,
      ValueFromPipeline=$True,
      ValueFromPipelineByPropertyName=$True)]
    [Alias('Input')]
      [String[]]$Stdin # PSCP
  )

  begin  {
    [String[]] $CollectedStdin = $Null

    if ( $AutoAcceptHostKey ) {
      $Args = @()

      if ( $Session   ) { $Args += @('-load', $Session  ) }
      if ( $User      ) { $Args += @('-l',    $User     ) }
      if ( $Password  ) { $Args += @('-pw',   $Password ) }
      if ( $Port      ) { $Args += @('-P',    $Port     ) }
      if ( $Hostname  ) { $Args += @( $Hostname         ) }

      Write-Verbose "& Plink.exe $Args"
      try {
        "y" | & Plink.exe $Args ':' | Out-Null
      } catch {
        throw "Exception running Plink.exe $Args : $_"
      }
    }

  }

  process {
    $CollectedStdin += $_
  }

  end {
    $Args = @()

    if ( $VerbosePreference -eq 'Continue' ) { $Args += @('-v') }
    if ( $Session                   ) { $Args += @( '-load',$Session        ) }
    if ( $User                      ) { $Args += @( '-l',   $User           ) }
    if ( $Password                  ) { $Args += @( '-pw',  $Password       ) }
    if ( $Port                      ) { $Args += @( '-P',   $Port           ) }
    if ( $CommandScript             ) { $Args += @( '-m',   $CommandScript  ) }
    if ( $PrivateKeyFile            ) { $Args += @( '-i',   $PrivateKeyFile ) }
    if ( $TunnelConfiguration              ) { $Args += @( '-nc',  $TunnelConfiguration   ) }
    if ( $SOCKSPortForwardConfiguration    ) { $Args += @( '-D',   $SOCKSPortForwardConfiguration   ) }
    if ( $LocalPortForwardConfiguration    ) { $Args += @( '-L',   $LocalPortForwardConfiguration   ) }
    if ( $RemotePortForwardConfiguration   ) { $Args += @( '-R',   $RemotePortForwardConfiguration  ) }
    if ( $SSHv1                     ) { $Args += @( '-1'  ) }
    if ( $SSHv2                     ) { $Args += @( '-2'  ) }
    if ( $IPv4                      ) { $Args += @( '-4'  ) }
    if ( $IPv6                      ) { $Args += @( '-6'  ) }
    if ( $EnableX11Forwarding       ) { $Args += @( '-X'  ) }
    if ( $DisableX11Forwarding      ) { $Args += @( '-x'  ) }
    if ( $EnableAgentForwarding     ) { $Args += @( '-A'  ) }
    if ( $DisableAgentForwarding    ) { $Args += @( '-a'  ) }
    if ( $EnablePTYAllocation       ) { $Args += @( '-t'  ) }
    if ( $DisablePTYAllocation      ) { $Args += @( '-t'  ) }
    if ( $EnableCompression         ) { $Args += @( '-C'  ) }
    if ( $SSH2SubSystem       ) { $Args += @( '-s'  ) }
    if ( $NoShell                   ) { $Args += @( '-N'  ) }
    if ( $DisableAgent              ) { $Args += @( '-noagent'  ) }
    if ( $Batch                     ) { $Args += @( '-batch'    ) }
    if ( $EnableAgent               ) { $Args += @( '-agent'    ) }
    if ( $PGPFingerPrint            ) { $Args += @( '-pgpfp'    ) }
    if ( $Hostname                  ) { $Args += @( $Hostname   ) }
    if ( $Command                   ) { $Args += @( $Command    ) }

    if ( $CollectedStdin ) {
      Write-Verbose "INPUT | & Plink.exe $Args"
      $CollectedStdin | & Plink.exe $Args
    }
    else {
      Write-Verbose "& Plink.exe $Args"
      & Plink.exe $Args
    }
  }
<#
.SYNOPSIS
Call Plink.exe with the arguments passed and execute commands on a SSH/Telnet/rlink host.

.DESCRIPTION
This function serves as a wrapper around the Plink.exe command line utility,
part of the PuTTY suite, which is used to run (SSH) commands on a remote host,
start interactive shells or create SSH tunnels.

This function constructs a Plink.exe command which is then invoked on the remote
host. All STDOUT/STDERR output from the Plink session are returned on STDOUT.

The documentation of parameters to this function is copied verbatim from the
Plink manual. Common PuTTY parameters are documented under the Invoke-PuTTY
function and only arguments exclusive to Plink.exe are documented here.
For the authoritative documentation of the Plink tool, refer to Chapter 7
(Using the command-line connection tool Plink) of the PuTTY documentation.
Also see RELATED LINKS below.

.LINK
Plink Documentation       - http://the.earth.li/~sgtatham/putty/0.58/htmldoc/Chapter7.html
Plink Command Line Usage  - http://the.earth.li/~sgtatham/putty/0.63/htmldoc/Chapter7.html#Plink-usage

.NOTES
Plink - PuTTY Link: command-line connection utility.
Documentation based on Release 0.60

.PARAMETER Command
The command to be executed on the remote host.

.PARAMETER SSH2SubSystem
-s  Remote command is an SSH subsystem command. SSH-2 only.

.EXAMPLE
Invoke-Plink -Session host.example.org -Password mysecret
# Launch a login shell in the same process (This shell is limited and not as rich as PuTTY).

.EXAMPLE
Invoke-Plink -Session mysession -CommandScript myscript.sh
# Run the contents of `myscript` line-by-line as commands on the remote host.

# NOTE: This is like a batch-file (not a script) where rhe commands are run
# one-by-one in the remote user's login/POSIX shell i.e. ksh(1), bash(1), etc.

# On some 'embedded' non-POSIX hosts e.g. Cisco IOS, etc, multi-line scripts
# are not supported and usually only the first line command is executed.

.EXAMPLE
$RemoteKernel = Invoke-Plink -Session host.example.org -Command 'uname -r'
# Retrieve the stdout of the remotely invoked command and use it in powershell.

.EXAMPLE
cat myfile.txt | Invoke-Plink -Session host.example.org -Command 'cd /tmp && cat -> myfile.txt'
# Copy a file over to the remote using redirection.

.EXAMPLE
Invoke-Plink -Session host.example.org -Command 'cat myfile.txt' | Out-File -Path myfile.txt
# Copy a file down using redirection.

#>
}

Set-Alias Plink Invoke-Plink

function Invoke-PSCP {
  [CmdletBinding()] Param(
    [Alias('Src', 'From', 'in')]
                        [String[]] $Source,     # PSCP
    [Alias('Dst', 'Destination', 'To', 'out')]
                        [String[]] $Target,     # PSCP
    [Alias('load')]     [String]   $Session,
    [Alias('l')]        [String]   $User,
    [Alias('pw')]       [String]   $Password,
    [Alias('i')]        [String]   $PrivateKeyFile,
    [Alias('P')]        [String]   $Port,
                        [Switch]   $Recursive,  # PSCP
                        [Switch]   $Quiet,      # PSCP
                        [Switch]   $PreserveFileAttributes, # PSCP
                        [Switch]   $UnsafeServerWildcards,  # PSCP
                        [Switch]   $SFTP,       # PSCP
                        [Switch]   $SCP,        # PSCP
    [Alias('1')]        [Switch]   $SSHv1,
    [Alias('2')]        [Switch]   $SSHv2,
    [Alias('4')]        [Switch]   $IPv4,
    [Alias('6')]        [Switch]   $IPv6,
    [Alias('ls')]       [Switch]   $List,
                        [Switch]   $Batch,
    [Alias('pgpfp')]    [Switch]   $PGPFingerPrint,
    [Alias('C')]        [Switch]   $EnableCompression,
    [Alias('noagent')]  [Switch]   $DisableAgent,
    [Alias('agent')]    [Switch]   $EnableAgent,
    [Alias('V')]        [Switch]   $DisplayVersion
  )

  $Args = @()
  # if ( $VerbosePreference -eq 'Continue' ) { $Args += @('-v') }
  if ( $Session                 ) { $Args += @( '-load', "$Session"         ) }
  if ( $User                    ) { $Args += @( '-l',    "$User"            ) }
  if ( $Password                ) { $Args += @( '-pw',   "$Password"        ) }
  if ( $Port                    ) { $Args += @( '-P',    "$Port"            ) }
  if ( $PrivateKeyFile          ) { $Args += @( '-i',    "$PrivateKeyFile"  ) }
  if ( $DisableAgent            ) { $Args += @( '-noagent'  ) }
  if ( $EnableAgent             ) { $Args += @( '-agent'    ) }
  if ( $Batch                   ) { $Args += @( '-batch'    ) }
  if ( $UnsafeServerWildcards   ) { $Args += @( '-unsafe'   ) }
  if ( $SFTP                    ) { $Args += @( '-sftp'     ) }
  if ( $SCP                     ) { $Args += @( '-scp'      ) }
  if ( $PGPFingerPrint          ) { $Args += @( '-pgpfp'    ) }
  if ( $Recursive               ) { $Args += @( '-r'  ) }
  if ( $SSHv1                   ) { $Args += @( '-1'  ) }
  if ( $SSHv2                   ) { $Args += @( '-2'  ) }
  if ( $IPv4                    ) { $Args += @( '-4'  ) }
  if ( $IPv6                    ) { $Args += @( '-6'  ) }
  if ( $EnableCompression       ) { $Args += @( '-C'  ) }
  if ( $PreserveFileAttributes  ) { $Args += @( '-p'  ) }
  if ( $Quiet                   ) { $Args += @( '-q'  ) }
  if ( $DisplayVersion          ) { $Args += @( '-V'  ) }
  if ( $List                    ) { $Args += @( '-ls' ) }
  if ( $Source                  ) { $Args += @( $Source ) }
  if ( $Target                  ) { $Args += @( $Target ) }

  $pinfo = New-Object System.Diagnostics.ProcessStartInfo
  $pinfo.FileName  = "PSCP.exe"
  $pinfo.Arguments = @('-v', $Args | %{$_})
  $pinfo.WorkingDirectory = $PWD
  $pinfo.RedirectStandardError = $true
  $pinfo.RedirectStandardOutput = $true
  $pinfo.UseShellExecute = $false
  $p = New-Object System.Diagnostics.Process

  Write-Verbose "Invoking : $($pinfo.Filename) $($pinfo.Arguments)"
  $p.StartInfo = $pinfo
  Write-Verbose "  Starting process"
  $p.Start() | Out-Null
  Write-Verbose "  Waiting for exit"
  $p.WaitForExit()
  Write-Verbose "  ExitCode : $($p.ExitCode)"

  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()

  $FileProcessedRecord = @()

  Write-Verbose "  Processing output .."
  if ( $p.ExitCode -eq 0 ) {
    $stderr -split "`n" | ?{ $_ -imatch '^Sending file' } | %{
      ($File, $Size) = ([Regex]::Match($_, "Sending file (.+), size=(.+)")).Groups[1,2]    
      $F = New-Object PSObject;
      $F |  Add-Member -PassThru  NoteProperty FileName $File |
            Add-Member            NoteProperty Size     $Size
      $FileProcessedRecord += @( $F )
    }

    $stdout -split "`n" | % -begin {$c=0} {
      ($File, $SizeKb, $SpeedKbs, $Eta, $Percent) = $_ -split "\s+\|\s+"
      try { $Eta      = [TimeSpan]($Eta -replace "ETA:\s", "")  } catch {}

      if ( $o = $FileProcessedRecord[$c] ) {
        $o |  Add-Member -PassThru  NoteProperty SizeReadable     $SizeKb     |
              Add-Member -PassThru  NoteProperty SpeedKbs         $SpeedKbs   |
              Add-Member -PassThru  NoteProperty TimeTaken        $Eta        |
              Add-Member -PassThru  NoteProperty PercentComplete  $Percent    |
              Add-Member -PassThru  NoteProperty FileNameOther    $File
      }
      $c++
    }

  }
  else {
    $ErrStr = $stderr -split "`n" | ?{$_ -notmatch '^(Looking|Server
        version|We|Doing|Host|ssh-rsa|Initialised|.*pageant.*|UsingAccess|Open|Start|Using|Connect|Sent|Access|Server|Disconnect)'} 
    $ErrStr = $ErrStr | ?{ $_ -notmatch '^Sending' }
    Throw "Non-Zero status code returned from 'pscp.exe $Args' : $ErrStr"
  }

<#
.SYNOPSIS
Call PSCP.exe with the parameters passed to copy files to/from an SSH host.

.DESCRIPTION
This function serves as a wrapper around the PSCP.exe (PuTTY Secure Copy Client)
command line utility, part of the PuTTY suite, which is used to copy files
and directories to/from an SSH host.

This function constructs a PSCP.exe command which is then invoked on the remote
host. All STDOUT/STDERR output from the PSCP session are returned on STDOUT.

The documentation of parameters to this function is copied verbatim from the
PSCP manual. Common PuTTY parameters are documented under the Invoke-PuTTY
function and only arguments exclusive to PSCP.exe are documented here.
For the authoritative documentation of PSCP, refer to Chapter 5
(Using PSCP to transfer files securely) of the PuTTY documentation.
See RELATED LINKS below.

.EXAMPLE
Invoke-PSCP -Source *.txt -Target example.com:/tmp/
# Copy (Local-To-Remote) all .txt files to /tmp/ on example.com (using SSH).

.EXAMPLE
Invoke-PSCP -Source example.com:/etc/hosts -Target foo
# Copy (Remote-To-Local) /etc/hosts from the remote host to a file named foo.

.EXAMPLE
Invoke-PSCP -Source example.com:/etc/hosts -Target foo.com:/etc/
# Copy (Remote-To-Remote) /etc/hosts from example.com to /etc/hosts on foo.com.

.LINK
PSCP Documentation      - http://the.earth.li/~sgtatham/putty/0.63/htmldoc/Chapter5.html
PSCP Command Line Usage - http://the.earth.li/~sgtatham/putty/0.63/htmldoc/Chapter5.html#pscp-usage

.NOTES
PSCP.exe - PuTTY Secure Copy client
Documentation of parameters based on Release 0.60

.PARAMETER Recursive
-r  Copy directories recursively.

.PARAMETER Quiet
-q  Quiet, do not show statistics.

.PARAMETER PreserveFileAttributes
-p  Preserve file attributes (where possible).

.PARAMETER UnsafeServerWildcards
-unsafe  Allow server-side wildcards (dangerous).

.PARAMETER SFTP
-sftp  Force use of the SFTP protocol.

.PARAMETER SCP
-scp  Force use of the SCP protocol.

.PARAMETER List
-ls  List files by filespec.

#>
}

Set-Alias PSCP Invoke-PScp

function New-PuTTYSession {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)] [ValidateNotNullOrEmpty()]
      [String] $Hostname,
    [String] $UserName              = $Env:USERNAME,
    [String] $SessionName           = $Hostname,

    [ValidateSet(0,1,2)]
    [UInt32] $AddressFamily         =  [UInt32] "0x00000000",
    [ValidateSet(0,1)]
    [UInt32] $AgentFwd              =  [UInt32] "0x00000000",#s
    [UInt32] $AltF4                 =  [UInt32] "0x00000001",#s
    [UInt32] $AltOnly               =  [UInt32] "0x00000000",#s
    [UInt32] $AltSpace              =  [UInt32] "0x00000000",#s
    [UInt32] $AlwaysOnTop           =  [UInt32] "0x00000000",#s
    [UInt32] $ANSIColour            =  [UInt32] "0x00000001",#s
    [String] $Answerback            =  [String] "PuTTY",
    [UInt32] $ApplicationCursorKeys =  [UInt32] "0x00000000",
    [UInt32] $ApplicationKeypad     =  [UInt32] "0x00000000",
    [UInt32] $AuthGSSAPI            =  [UInt32] "0x00000001",#s
    [UInt32] $AuthKI                =  [UInt32] "0x00000001",#s
    [UInt32] $AuthTIS               =  [UInt32] "0x00000000",#s
    [UInt32] $AutoWrapMode          =  [UInt32] "0x00000001",#s
    [UInt32] $BackspaceIsDelete     =  [UInt32] "0x00000001",#s
    [UInt32] $BCE                   =  [UInt32] "0x00000001",#s
    [UInt32] $Beep                  =  [UInt32] "0x00000001",#s
    [UInt32] $BeepInd               =  [UInt32] "0x00000000",#s
    [UInt32] $BellOverload          =  [UInt32] "0x00000001",
    [UInt32] $BellOverloadN         =  [UInt32] "0x00000005",
    [UInt32] $BellOverloadS         =  [UInt32] "0x00001388",
    [UInt32] $BellOverloadT         =  [UInt32] "0x000007d0",
    [String] $BellWaveFile          =  [String] "",
    [UInt32] $BlinkCur              =  [UInt32] "0x00000000",#s
    [UInt32] $BlinkText             =  [UInt32] "0x00000000",#s
    [UInt32] $BoldAsColour          =  [UInt32] "0x00000000",#s
    [String] $BoldFont              =  [String] "",
    [UInt32] $BoldFontCharSet       =  [UInt32] "0x00000000",
    [UInt32] $BoldFontHeight        =  [UInt32] "0x00000000",
    [UInt32] $BoldFontIsBold        =  [UInt32] "0x00000000",#s
    [UInt32] $BugDeriveKey2         =  [UInt32] "0x00000000",
    [UInt32] $BugHMAC2              =  [UInt32] "0x00000000",
    [UInt32] $BugIgnore1            =  [UInt32] "0x00000000",#s
    [UInt32] $BugIgnore2            =  [UInt32] "0x00000000",#s
    [UInt32] $BugMaxPkt2            =  [UInt32] "0x00000000",
    [UInt32] $BugPKSessID2          =  [UInt32] "0x00000000",
    [UInt32] $BugPlainPW1           =  [UInt32] "0x00000000",
    [UInt32] $BugRekey2             =  [UInt32] "0x00000000",
    [UInt32] $BugRSA1               =  [UInt32] "0x00000000",
    [UInt32] $BugRSAPad2            =  [UInt32] "0x00000000",
    [UInt32] $BugWinadj             =  [UInt32] "0x00000000",
    [UInt32] $CapsLockCyr           =  [UInt32] "0x00000000",
    [UInt32] $ChangeUsername        =  [UInt32] "0x00000000",#s
    [String] $Cipher                =  [String] "aes,blowfish,3des,WARN,arcfour,des",
    [UInt32] $CJKAmbigWide          =  [UInt32] "0x00000000",
    [ValidateSet(0,1,2)]
    [UInt32] $CloseOnExit           =  [UInt32] "0x00000001",
    [String] $Colour0               =  [String] "187,187,187",
    [String] $Colour10              =  [String] "0,187,0",
    [String] $Colour11              =  [String] "85,255,85",
    [String] $Colour12              =  [String] "187,187,0",
    [String] $Colour1               =  [String] "255,255,255",
    [String] $Colour13              =  [String] "255,255,85",
    [String] $Colour14              =  [String] "0,0,187",
    [String] $Colour15              =  [String] "85,85,255",
    [String] $Colour16              =  [String] "187,0,187",
    [String] $Colour17              =  [String] "255,85,255",
    [String] $Colour18              =  [String] "0,187,187",
    [String] $Colour19              =  [String] "85,255,255",
    [String] $Colour2               =  [String] "0,0,0",
    [String] $Colour20              =  [String] "187,187,187",
    [String] $Colour21              =  [String] "255,255,255",
    [String] $Colour3               =  [String] "85,85,85",
    [String] $Colour4               =  [String] "0,0,0",
    [String] $Colour5               =  [String] "0,255,0",
    [String] $Colour6               =  [String] "0,0,0",
    [String] $Colour7               =  [String] "85,85,85",
    [String] $Colour8               =  [String] "187,0,0",
    [String] $Colour9               =  [String] "255,85,85",
    [UInt32] $ComposeKey            =  [UInt32] "0x00000000",
    [UInt32] $Compression           =  [UInt32] "0x00000000",#s
    [UInt32] $CRImpliesLF           =  [UInt32] "0x00000000",#s
    [UInt32] $CtrlAltKeys           =  [UInt32] "0x00000001",#s
    [UInt32] $CurType               =  [UInt32] "0x00000000",
    [UInt32] $DECOriginMode         =  [UInt32] "0x00000000",#s
    [UInt32] $DisableArabicShaping  =  [UInt32] "0x00000000",#s
    [UInt32] $DisableBidi           =  [UInt32] "0x00000000",#s
    [String] $Environment           =  [String] "",
    [UInt32] $EraseToScrollback     =  [UInt32] "0x00000001",#s
    [UInt32] $FontCharSet           =  [UInt32] "0x00000000",
    [String] $Font                  =  [String] "Courier New",
    [UInt32] $FontHeight            =  [UInt32] "0x0000000a",
    [UInt32] $FontIsBold            =  [UInt32] "0x00000000",#s
    [UInt32] $FontQuality           =  [UInt32] "0x00000000",
    [UInt32] $FontVTMode            =  [UInt32] "0x00000004",
    [UInt32] $FullScreenOnAltEnter  =  [UInt32] "0x00000000",
    [UInt32] $GssapiFwd             =  [UInt32] "0x00000000",#s
    [String] $GSSCustom             =  [String] "",
    [String] $GSSLibs               =  [String] "gssapi32,sspi,custom",
    [UInt32] $HideMousePtr          =  [UInt32] "0x00000000",#s
    [String] $KEX                   =  [String] "dh-gex-sha1,dh-group14-sha1,dh-group1-sha1,rsa,WARN",
    [UInt32] $LFImpliesCR           =  [UInt32] "0x00000000",#s
    [String] $LineCodePage          =  [String] "",
    [UInt32] $LinuxFunctionKeys     =  [UInt32] "0x00000000",
    [UInt32] $LocalEcho             =  [UInt32] "0x00000002",
    [UInt32] $LocalEdit             =  [UInt32] "0x00000002",
    [UInt32] $LocalPortAcceptAll    =  [UInt32] "0x00000000",#s
    [String] $LocalUserName         =  [String] "",
    [UInt32] $LockSize              =  [UInt32] "0x00000000",
    [Switch] $LogAllSessionOutput,
    [UInt32] $LogFileClash          =  [UInt32] "0xffffffff",
    [String] $LogFileName           =  [String] "putty.log",
    [Switch] $LogFileAppend,
    [Switch] $LogFileAskUser,
    [Switch] $LogFileOverwrite,
    [UInt32] $LogFlush              =  [UInt32] "0x00000001",#s
    [String] $LogHost               =  [String] "",
    [UInt32] $LoginShell            =  [UInt32] "0x00000001",#s
    [Switch] $LogNone,
    [Switch] $LogPrintableOutput,
    [Switch] $LogSSHPackets,
    [Switch] $LogSSHPacketsAndRawData,
    [UInt32] $LogType               =  [UInt32] "0x00000004",
    [UInt32] $MouseIsXterm          =  [UInt32] "0x00000000",#s
    [UInt32] $MouseOverride         =  [UInt32] "0x00000001",#s
    [UInt32] $NetHackKeypad         =  [UInt32] "0x00000000",
    [UInt32] $NoAltScreen           =  [UInt32] "0x00000000",#s
    [UInt32] $NoApplicationCursors  =  [UInt32] "0x00000000",#s
    [UInt32] $NoApplicationKeys     =  [UInt32] "0x00000000",#s
    [UInt32] $NoDBackspace          =  [UInt32] "0x00000000",#s
    [UInt32] $NoMouseReporting      =  [UInt32] "0x00000000",#s
    [UInt32] $NoPTY                 =  [UInt32] "0x00000000",#s
    [UInt32] $NoRemoteCharset       =  [UInt32] "0x00000000",#s
    [UInt32] $NoRemoteResize        =  [UInt32] "0x00000000",#s
    [UInt32] $NoRemoteWinTitle      =  [UInt32] "0x00000000",#s
    [UInt32] $PassiveTelnet         =  [UInt32] "0x00000000",
    [UInt32] $PasteRTF              =  [UInt32] "0x00000000",#s
    [UInt32] $PingInterval          =  [UInt32] "0x00000000",
    [UInt32] $PingIntervalSecs      =  [UInt32] "0x00000000",
    [String] $PortForwardings       =  [String] "",
    [ValidateRange(1,65535)]
    [UInt32] $PortNumber            =  [UInt32] "0x00000016",
    [UInt32] $Present               =  [UInt32] "0x00000001",#s
    [String] $Printer               =  [String] "",
    [ValidateSet('raw', 'telnet', 'rlogin', 'ssh', 'serial')]
    [String] $Protocol              =  [String] "ssh",
    [UInt32] $ProxyDNS              =  [UInt32] "0x00000001",#s
    [String] $ProxyExcludeList      =  [String] "",
    [String] $ProxyHost             =  [String] "proxy",
    [UInt32] $ProxyLocalhost        =  [UInt32] "0x00000000",#s
    [UInt32] $ProxyMethod           =  [UInt32] "0x00000000",
    [String] $ProxyPassword         =  [String] "",
    [UInt32] $ProxyPort             =  [UInt32] "0x00000050",
    [String] $ProxyTelnetCommand    =  [String] "connect %host %port\\n",
    [String] $ProxyUsername         =  [String] "",
    [String] $PublicKeyFile         =  [String] "",
    [UInt32] $RawCNP                =  [UInt32] "0x00000000",#s
    [UInt32] $RectSelect            =  [UInt32] "0x00000000",
    [String] $RekeyBytes            =  [String] "1G",
    [UInt32] $RekeyTime             =  [UInt32] "0x0000003c",
    [String] $RemoteCommand         =  [String] "",
    [UInt32] $RemotePortAcceptAll   =  [UInt32] "0x00000000",#s
    [UInt32] $RemoteQTitleAction    =  [UInt32] "0x00000001",
    [UInt32] $RFCEnviron            =  [UInt32] "0x00000000",
    [UInt32] $RXVTHomeEnd           =  [UInt32] "0x00000000",
    [UInt32] $ScrollbackLines       =  [UInt32] "0x000007d0",
    [UInt32] $ScrollBar             =  [UInt32] "0x00000001",#s
    [UInt32] $ScrollBarFullScreen   =  [UInt32] "0x00000000",#s
    [UInt32] $ScrollbarOnLeft       =  [UInt32] "0x00000000",#s
    [UInt32] $ScrollOnDisp          =  [UInt32] "0x00000001",#s
    [UInt32] $ScrollOnKey           =  [UInt32] "0x00000000",#s
    [UInt32] $SerialDataBits        =  [UInt32] "0x00000008",
    [UInt32] $SerialFlowControl     =  [UInt32] "0x00000001",
    [String] $SerialLine            =  [String] "COM1",
    [UInt32] $SerialParity          =  [UInt32] "0x00000000",
    [UInt32] $SerialSpeed           =  [UInt32] "0x00002580",
    [UInt32] $SerialStopHalfbits    =  [UInt32] "0x00000002",
    [UInt32] $ShadowBold            =  [UInt32] "0x00000000",#s
    [UInt32] $ShadowBoldOffset      =  [UInt32] "0x00000001",
    [UInt32] $SSH2DES               =  [UInt32] "0x00000000",
    [UInt32] $SshBanner             =  [UInt32] "0x00000001",#s
    [UInt32] $SSHLogOmitData        =  [UInt32] "0x00000000",#s
    [UInt32] $SSHLogOmitPasswords   =  [UInt32] "0x00000001",#s
    [UInt32] $SshNoAuth             =  [UInt32] "0x00000000",#s
    [UInt32] $SshNoShell            =  [UInt32] "0x00000000",#s
    [UInt32] $SshProt               =  [UInt32] "0x00000002",
    [UInt32] $StampUtmp             =  [UInt32] "0x00000001",
    [UInt32] $SunkenEdge            =  [UInt32] "0x00000000",
    [UInt32] $TCPKeepalives         =  [UInt32] "0x00000000",#s
    [UInt32] $TCPNoDelay            =  [UInt32] "0x00000001",#s
    [UInt32] $TelnetKey             =  [UInt32] "0x00000000",
    [UInt32] $TelnetRet             =  [UInt32] "0x00000001",#s
    [UInt32] $TermHeight            =  [UInt32] "0x00000018",
    [String] $TerminalModes         =  [String] "CS7=A,CS8=A,DISCARD=A,DSUSP=A,ECHO=A,ECHOCTL=A,ECHOE=A,ECHOK=A,ECHOKE=A,ECHONL=A,EOF=A,EOL=A,EOL2=A,ERASE=A,FLUSH=A,ICANON=A,ICRNL=A,IEXTEN=A,IGNCR=A,IGNPAR=A,IMAXBEL=A,INLCR=A,INPCK=A,INTR=A,ISIG=A,ISTRIP=A,IUCLC=A,IXANY=A,IXOFF=A,IXON=A,KILL=A,LNEXT=A,NOFLSH=A,OCRNL=A,OLCUC=A,ONLCR=A,ONLRET=A,ONOCR=A,OPOST=A,PARENB=A,PARMRK=A,PARODD=A,PENDIN=A,QUIT=A,REPRINT=A,START=A,STATUS=A,STOP=A,SUSP=A,SWTCH=A,TOSTOP=A,WERASE=A,XCASE=A",
    [String] $TerminalSpeed         =  [String] "38400,38400",
    [String] $TerminalType          =  [String] "xterm",
    [UInt32] $TermWidth             =  [UInt32] "0x00000050",
    [UInt32] $TryAgent              =  [UInt32] "0x00000001",#s
    [UInt32] $TryPalette            =  [UInt32] "0x00000000",#s
    [UInt32] $UserNameFromEnvironment =  [UInt32] "0x00000000",#s
    [UInt32] $UseSystemColours      =  [UInt32] "0x00000000",#s
    [UInt32] $UTF8Override          =  [UInt32] "0x00000001",#s
    [UInt32] $WarnOnClose           =  [UInt32] "0x00000001",#s
    [String] $WideBoldFont          =  [String] "",
    [UInt32] $WideBoldFontCharSet   =  [UInt32] "0x00000000",
    [UInt32] $WideBoldFontHeight    =  [UInt32] "0x00000000",
    [UInt32] $WideBoldFontIsBold    =  [UInt32] "0x00000000",#s
    [String] $WideFont              =  [String] "",
    [UInt32] $WideFontCharSet       =  [UInt32] "0x00000000",
    [UInt32] $WideFontHeight        =  [UInt32] "0x00000000",
    [UInt32] $WideFontIsBold        =  [UInt32] "0x00000000",#s
    [UInt32] $WindowBorder          =  [UInt32] "0x00000001",
    [String] $WindowClass           =  [String] "",
    [UInt32] $WinNameAlways         =  [UInt32] "0x00000001",#s
    [String] $WinTitle              =  [String] "",
    [String] $Wordness0             =  [String] "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0",
    [String] $Wordness128           =  [String] "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1",
    [String] $Wordness160           =  [String] "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1",
    [String] $Wordness192           =  [String] "2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2",
    [String] $Wordness224           =  [String] "2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2",
    [String] $Wordness32            =  [String] "0,1,2,1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,1,1,1,1",
    [String] $Wordness64            =  [String] "1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,1,1,2",
    [String] $Wordness96            =  [String] "1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,1,1,1",
    [String] $X11AuthFile           =  [String] "",
    [UInt32] $X11AuthType           =  [UInt32] "0x00000001",
    [String] $X11Display            =  [String] "",
    [UInt32] $X11Forward            =  [UInt32] "0x00000000",#s
    [UInt32] $Xterm256Colour        =  [UInt32] "0x00000001",#s

    [Switch] $Force
  )

    [UInt32] $LogType = `
      if     ( $LogNone                 ) { [UInt32] "0x00000000" }
      elseif ( $LogPrintableOutput      ) { [UInt32] "0x00000001" }
      elseif ( $LogAllSessionOutput     ) { [UInt32] "0x00000002" }
      elseif ( $LogSSHPackets           ) { [UInt32] "0x00000003" }
      elseif ( $LogSSHPacketsAndRawData ) { [UInt32] "0x00000004" }
      else                                { [UInt32] "0x00000000" }

    [UInt32] $LogFileClash = `
      if     ( $LogFileAppend    ) { [UInt32] "0x00000000" }
      elseif ( $LogFileOverwrite ) { [UInt32] "0x00000001" }
      elseif ( $LogFileAskUser   ) { [UInt32] "0xFFFFFFFF" }
      else                         { [UInt32] "0xFFFFFFFF" }

  if ( $Hostname -imatch '@' ) {
    ($Username, $Hostname) = ($Hostname -split '@')[0,1]
  }

  if ( $Hostname -imatch ':' ) {
    ($Hostname, $PortNumber) = ($Hostname -split ':')[0,1]
  }

  $Params         = $MyInvocation.MyCommand.Parameters
  $FunctionParams = $Params.Keys | ?{ -not($Params.$_.Aliases) -and -not($Params.$_.Name -eq 'Force') }

  $BasePath = "HKCU:\Software\SimonTatham\PuTTY\Sessions\$SessionName"
  if ( -not (Test-Path $BasePath) ) {
    mkdir $BasePath -Verbose:$VerbosePreference -Force | Write-Verbose
  }
  $RegKey = Get-Item $BasePath

  $CurrentParameterSet = $MyInvocation.MyCommand.ParameterSets | ?{ $_.Name -eq $PSCmdlet.ParameterSetName }
  $WantedParameters    = $CurrentParameterSet.Parameters | ?{
    -not($_.Aliases) -and -not($_.ParameterType -ilike '*Switch*') -and -not($_.Name -eq 'Force')
  }

  # Create a .reg file to import into the registry
  $RegFileLines = @(  'Windows Registry Editor Version 5.00', '', "[$($RegKey.Name)]" )

  foreach ( $Param in $WantedParameters ) {
    $Key = $Param.Name
    $Value = $ExecutionContext.InvokeCommand.ExpandString( (cat Variable:\$Key) )

    $ValueFormatted = switch -regex ( $Param.ParameterType ) {
      'String' {
        "`"$Value`""; break;
      }
      'UInt32' {
        $HexString = "{0:X8}" -f ([UInt32]$Value)
        "dword:$HexString"; break;
      }
    }
    $RegFileLines += @( "`"$Key`"=$ValueFormatted" )
  }

  $RegFile = (Join-Path $Env:TEMP "PuTTY-$Hostname.session.reg")
  $RegFileLines -join "`r`n" | Out-File $RegFile -Force

  try {
    & reg.exe import $RegFile 2>&1 | Write-Verbose
  } catch {
    if ( $_ -notlike '*The operation completed successfully.*' ) { # reg.exe is broken
      Throw "reg.exe, failed importing '$RegFile' : $_"
    }
  }

<#
.SYNOPSIS
Creates (or overwrites) a PuTTY saved session if it does not exist.

.DESCRIPTION
Sets the parameters required for a saved PuTTY session which is stored in the
registry. The saved session can then be used in subsequent calls to functions
like Invoke-PuTTY, Invoke-Plink, Invoke-PScp, etc (via the -Session param).
The default values for a saved session as used by PuTTY are used to populate
the registry values (unless overridden), therefore sessions created by PuTTY
are compatible with these calls.

The minimum set of parameters often required are SessionName, Username and
Hostname. No passwords are stored in the registry and so this must be passed
in to each function (via the -Password param) or alternatively, private keys
must be used (via the -PrivateKeyFile param).

.EXAMPLE
New-PuttySession -Session server1 -Hostname foo.example.com -Username root
# Create a simple session, no decorations - default to putty defaults.

.EXAMPLE
New-PuttySession -Session server1 -Hostname foo.example.com -Username root `
  -Compression $True -TryAgent $True
# Enable compression and attempt to use pageant if it is running.
#>
}

function Get-PuttySession {
  [CmdletBinding()] Param()

  $Sessions = Get-Item "HKCU:\Software\SimonTatham\PuTTY\Sessions\*"
  foreach ( $Session in $Sessions ) {
    Write-Verbose "$($Session.PSPath)"
    if ( $SavedSession = Get-ItemProperty $Session.PSPath ) {
      $Result = New-Object PSObject
      $Result | Add-Member NoteProperty Session   $SavedSession.PSChildName
      # | ?{ $_.Name -imatch '(?<!^PS.*)name*' }
      $SavedSession | gm -MemberType NoteProperty * | ?{ $_.Name -notlike 'PS*' } | %{ $_.Name } | %{
        $Result | Add-Member NoteProperty $_ $SavedSession.$_
      }
      $Result
    }
  }
}

function Remove-PuTTYSession {
  [CmdletBinding()] Param(
    [String] $SessionName
  )
  try {
    $BasePath = "HKCU:\Software\SimonTatham\PuTTY\Sessions\$SessionName"
    if ( Test-Path $BasePath ) {
      rm -Force $BasePath -Verbose:$VerbosePreference
    }
  } catch {
    Throw "Exception while removing session '$SessionName' : $_"
  }
<#
.SYNOPSIS
Removes a PuTTY saved session from the registry.
#>
}

function Set-PuttySession {
  [CmdletBinding()] Param(
    [String]    $SessionName,
    [String]    $Key,
    [PSObject]  $Value,
    [Switch]    $Force
  )
  if ( $RegKey = Get-Item "HKCU:\Software\SimonTatham\PuTTY\Sessions\$SessionName" ) {
    New-ItemProperty -Path $RegKey.PSPath -Name $Key -Value $Value -Force:$Force
  }
  else {
    Throw "Error, SessionName '$SessionName' not found."
  }
}

function Start-Pageant {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)]
      [String[]] $KeyFiles,
    [String]   $Command
  )
  if ( $KeyFiles ) {
    $KeyFiles = $KeyFiles | %{ if (Test-Path $_) { Resolve-Path $_ } else { $_ } }
  }

  if ( $Command ) {
    Write-Verbose "Pageant.exe $KeyFiles -c $Command"
    & Pageant.exe $KeyFiles -c $Command
  }
  elseif ( $KeyFiles ) {
    Write-Verbose "Pageant.exe $KeyFiles"
    & Pageant.exe $KeyFiles
  }
<#
.SYNOPSIS
Start an instance of the Pageant SSH authentication agent.

.DESCRIPTION
Pageant is an SSH authentication agent. It holds SSH private keys in memory,
already loaded and decoded (from *.ppk files), so that these keys can be
accessed by SSH tools like PuTTY, Plink, PSCP, pftp and even WinSCP, etc
without needing to type a passphrase to authenticate over SSH. In effect,
this enables SSH public key authentication.

For authoritative information on the Pageant.exe tool, refer to Chapter 9
(Using Pageant for authentication) of the PuTTY documentation.

.LINK
http://the.earth.li/~sgtatham/putty/0.63/htmldoc/Chapter9.html
#>
}

Set-Alias Pageant Invoke-Pageant

function Stop-Pageant {
  [CmdletBinding()] Param(
    [Switch]$Force
  )
  Get-Process Pageant | Stop-Process -Force:$Force -Verbose:$VerbosePreference
<#
.SYNOPSIS
Stop running instances of the Pageant SSH authentication agent.
#>
}

function Invoke-PuTTYGen {
  [CmdletBinding()] Param(
    [Parameter(Mandatory=$True)]
      [String[]] $KeyFiles
  )
  if ( $KeyFiles ) {
    $KeyFiles = $KeyFiles | %{ if (Test-Path $_) { Resolve-Path $_ } else { $_ } }
  }
  Write-Verbose "PuTTYGen.exe $KeyFiles"
  & PuTTYGen.exe $KeyFiles

<#
.SYNOPSIS
Invoke PuTTYGen to generate SSH RSA/DSA Keys/KeyFiles.

.DESCRIPTION
PuTTYGen is a SSH key generation and conversion tool. It can be used to
generate RSA and DSA SSH keypairs for use in SSH authentication (either
by loading them up into Pageant or by supplying them to SSH tools (-i)).

Currently, there is no way to automate PuTTYGen and so this function
just loads the PuTTYGen GUI.
#>
}
Set-Alias PuTTYGen Invoke-PuTTYGen

function Install-PuTTYSuite {
  [CmdletBinding()] Param(
    [String]    $TargetDirectory = $PuttyBasePath,
    [String]    $SourcePath,   # Offline install, from netshare, etc
    [String[]]  $Suite = $ToInstall,
    [String]    $Version = 'latest',
    [Switch]    $Extras,
    [Switch]    $Force
  )

  if ( Test-Path $TargetDirectory -PathType Leaf ) {
    Throw "Error, $TargetDirectory is a file .. cannot proceed."
  }

  if ( -not( Test-Path $TargetDirectory ) ) {
    mkdir -Force:$Force -Verbose:$VerbosePreference $TargetDirectory | Out-Null
  }

  $SrcUrl = "http://the.earth.li/~sgtatham/putty/$version/x86"

  if ( $Extras ) {
    $Suite += @( $PuttyExtras )
  }

  $Suite | %{
    if ( $Tool = @(gcm $_ -ea 0) ) {
      Write-Verbose "  '$_' ($($Tool[0].Definition)) already installed and available."
      if ( -not($Force) ) { return }
    }
    if ( $SourcePath ) {
      $TempFile = Join-Path $SourcePath $_
    } else {
      try {
        $Url = "$SrcUrl/$_"
        $TempFile = "$Env:Temp\$_"
        Write-Verbose "  Downloading '$Url' to '$TargetDirectory'"
        (New-Object System.Net.WebClient).DownloadFile($Url, $TempFile)
        Set-ItemProperty -Path $PuttyRegKey -Name $_ (Join-Path $TargetDirectory $_)
      } catch {
        throw "Error downloading '$Url' : $_"
      }
      cp $TempFile $TargetDirectory -Force:$Force -Verbose:$VerbosePreference
      Set-ItemProperty -Path $PuttyRegKey -Name $_ (Join-Path $TargetDirectory $_) -Force:$Force
    }
  }
<#
.SYNOPSIS
Install the PuTTY Suite of tools and make them available in the current shell.

.DESCRIPTION
Download and install the tools that necessary for the functionality of this
module. The list includes putty, plink, pscp, psftp, pageant, puttygen and
puttytel.

An Offline Install can be accomplished by specifying the path to the
SourcePath parameter e.g. for installs from a network path, etc.
#>
}

Export-ModuleMember -Function *-* -Alias *

# TODO
# Conrad
#   Set-PuTTYSessionParam
# Test Install
# PSFTP
# Documentation
# Examples
# plink needs to validate session exists - otherwise command gets invoked as the host to lookupw
# AutoAcceptHostKey needs to be a separate function.
# Record install location in registry
