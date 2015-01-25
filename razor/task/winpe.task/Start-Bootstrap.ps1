<#
.SYNOPSIS
   Script uses User-Data from DHCP server to get a sequence of bootstrap tasks

   Copyright (c) 2014 UK Test Automation, Citrix Systems UK Ltd.

.DESCRIPTION

   $ScriptCallbackStr should take a PSObject with BootStrapData. Default script
   assumes BootStrapData is a scriptblock string.
   $ScriptCallbackStr should return $true if the bootstrap sequence is complete
   (the startup bat file will be disabled) $false if the boot sqequnce is not
   complete (the startup bat file will be continue to run at each reboot)
   or throw if an error occurs
#>
param(
  [string]$ScriptCallbackStr,# script
  [int]$RetryWait = 1, # seconds
  [int]$RetryMax = 2,
  [int]$UserDataTimeout = 20000, # milliseconds
  [int]$Port = 80
)

function Get-ScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

$scriptDir = Get-ScriptDirectory
$logDir = Join-Path $ScriptDir 'log'
mkdir $logDir -Force -ea 0 | Out-Null


$startUpCmdRegKeyName = Join-Path $ScriptDir ('{0}.cmd' -f ([IO.FileInfo]($MyInvocation.MyCommand).Name).BaseName)
$startUpCmdRegKeyNameDisabled = "$startUpCmdRegKeyName -disabled"

#TODO check for CADI and ASF

$discovery     = Join-Path $scriptDir "Start-AsyncAsfDiscovery.ps1"
$cadiFw        = Join-Path $scriptDir "Set-CADIFirewall.ps1"
$networkScript = Join-Path $scriptDir "Invoke-DefaultBootstrapScript.ps1"

$sw = [Diagnostics.Stopwatch]::StartNew()

Start-Transcript -Path $logDir\bootstrap.log -append
$VerbosePreference = "continue"

$CadiFWSet = $false

try
{
#     test whether state enum has already been created, if not create it and set default state to failed
  $testState = [State]::Failed
}
catch
{
  Add-Type -TypeDefinition @"
   public enum State
   {
      Run,
      Disabled,
      Failed,
    TimedOut
   }
"@
}


# extend webclient to allow shorter timeout to be set
Add-Type -TypeDefinition @"
public class WebClientEx : System.Net.WebClient
{
    // Timeout in milliseconds
    // public int Timeout { get; set; }
    private int Timeout = 0;

    /// <summary>
    /// Sets default timeout
    /// </summary>
    public WebClientEx()
        : base()
    {
        this.Timeout = 1000;
    }

    /// <summary>
    /// Sets custom timeout
    /// </summary>
    /// <param name="timeout">Timeout in milliseconds</param>
    public WebClientEx(int timeout)
        : base()
    {
        this.Timeout = timeout;
    }

    /// <summary>
    /// Overriding base method to set timeout
    /// </summary>
    /// <param name="address">Server Url</param>
    /// <returns>A WebRequest with a timeout assigned</returns>
    protected override System.Net.WebRequest GetWebRequest(System.Uri address)
    {
        System.Net.WebRequest wr = base.GetWebRequest(address);
        wr.Timeout = this.Timeout;
        return wr;
    }
}
"@

$global:state = [State]::Failed


$complete = $false
$retryCount = 0
# if netwrok hasn't started yet wait for this time before retrying
$NoNetworkWaitInSecs = 10


if($ScriptCallbackStr -eq [string]::Empty)
{
  $ScriptCallback =
  {
    [CmdletBinding()]
      param(
          [parameter(
              mandatory=$true,position=0)][PSObject]$taskData
    )

    Write-Host "scriptblock $taskData"

    $scriptBlockStr = $taskData.BootStrapData

    try
    {
      $bootStrapComplete = Invoke-Expression -Command $scriptBlockStr
      Write-Host "Successfully run bootstrap tasks Return: $bootStrapComplete"

      return $bootStrapComplete
    }
    catch
    {
      Write-Warning "Error caught running Bootstrap tasks: $($Error[0])"
      throw $Error[0]
    }

    return $false
  }
}
else
{
  # convert the scriptblock string to a scriptblock
  $ScriptCallback = $executioncontext.invokecommand.NewScriptBlock($ScriptCallbackStr)
}




Function Get-UserData
{
  param(
    [string]$UserDataServer
  )

  $webClient = new-object WebClientEx -ArgumentList @($UserDataTimeout)

  $webClient.Headers.Add("user-agent", "PowerShell")

  $uri = [Uri]"http://$($UserDataServer):$($port)/latest/user-data"

  Write-Host "Get-UserData: Try to get user data from $uri"

  $userData = $null

  try
  {
    $userData = $webClient.DownloadString($uri.ToString())
  }
  catch
  {
    Write-Warning $Error[0]
    return [State]::Failed
  }

  if([string]::IsNullOrEmpty($userData))
  {
    Write-Host "Get-UserData: User data found at $uri but is empty"
    return [State]::Disabled
  }
  else
  {
    Write-Verbose "Get-UserData: Got $userData from userdata from $uri"

    $BootStrapData = New-Object PSObject
        $BootStrapData | add-member Noteproperty BootStrapData $userData

    # pass the userdata to the callback script

    try
    {
      $result = Invoke-Command -ScriptBlock $ScriptCallback -ArgumentList $BootStrapData
      Write-Verbose "Get-UserData: ScriptCallback result: $result"

      if($result -ne $false -and $result -ne $true)
      {
        Write-Warning "Get-UserData: ScriptCallback must return either true or false or throw on error"
        return [State]::Failed
      }

      if($result)
      {
        Write-Host "Get-UserData: Script callback complete: bootstrap sequence complete"
        return [State]::Disabled
      }
      else
      {
        Write-Host "Get-UserData: Script callback complete: bootstrap sequence not complete"
        return [State]::Run
      }

    }
    catch
    {
      Write-Warning "Get-UserData: Error caught running script call back tasks $($Error[0])"
    }
  }

  return [State]::Failed

}

Write-Host "Main: Bootstrap using User-data"



while($true)
{
  # get all the interfaces for this machine from inside loop in case DHCP is slow
  # exclude IPv4 LinkLayerAddress address 169.254.x.x as Udpclient fails
  $nics = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()| Where-Object{$_.OperationalStatus -eq "Up"}

  $nics = $nics | Where-Object{($_.NetworkInterfaceType -eq [System.Net.NetworkInformation.NetworkInterfaceType]::Ethernet) -or  ($_.NetworkInterfaceType -eq [System.Net.NetworkInformation.NetworkInterfaceType]::Wireless80211)}

  if($nics -eq $null -or $nics.Count -eq 0)
  {
    Write-Warning "Main: Network not present. Wait $NoNetworkWaitInSecs secs and try again"
    sleep $NoNetworkWaitInSecs
    continue
  }

  $dhcpservers = @($nics | foreach{$_.GetIPProperties()} | foreach{$_.DhcpServerAddresses} | foreach {$_.IPAddressToString  })

  if($dhcpservers.Count -eq 0)
  {
    Write-Warning "Main: No DHCP servers found"
  }

  try
  {
    $dhcpservers | foreach{
            try
            {
              $global:state = Get-UserData -UserDataServer $_
            }
            catch
            {
              Write-Warning "Main: Get UserData failed: $($Error[0])"
            }
          }

    if($global:state -ne [State]::Failed)
    {
        Write-Host "Main: Userdata excecution complete"
        break;
    }
  }
  catch
  {
    Write-Warning "Main: Userdata excecution failed: $($Error[0])"
  }

  &$discovery

  if($global:state -eq [State]::Disabled)
  {
      Write-Host "Main: ASF discovery excecution complete"
      break;
  }

  if(-not $CadiFWSet)
  {
    &$cadiFw
    $CadiFWSet = $true
  }

  $retryCount ++

  $global:state = [State]::Failed

  if($retryCount -eq $RetryMax)
  {
    Write-Warning "Main: Bootstrap execution has been attempted $retryCount times. Exit retry and set default settings"
    $global:state = [State]::TimedOut
    break
  }


  Write-Host "Main: Attempt[$retryCount of $RetryMax]: Bootstrap execution failed. Wait $RetryWait secs and try again"
  sleep $RetryWait
}


if($global:state -ne [State]::TimedOut)
{
  if($global:state -eq [State]::Disabled)
  {
    Write-Warning "Main: Bootstrap script has reported that bootstrap process is complete. Disable startup cmd in registry"

    Set-ItemProperty -Path "HKLM:\software\microsoft\windows\currentversion\run" -Name $startUpCmdRegKeyName -Value $startUpCmdRegKeyNameDisabled
  }
  else
  {
    Write-Warning "Main: Bootstrap script has reported that bootstrap process is not yet complete. Startup cmd will be run after all re-boots"
  }
}
else
{
  # run the default network script
  try
  {
    Write-Host "Defaulting and looking to run network script '$networkScript'"
    if (Test-Path $networkScript) {
      Write-Host "  Network script '$networkScript' exists, invoking."
      & $networkScript
    }
  }
  catch
  {
    Write-Warning $Error[0]
  }

  #if timed out disable the startup task in registry
  Set-ItemProperty -Path "HKLM:\software\microsoft\windows\currentversion\run" -Name $startUpCmdRegKeyName -Value $startUpCmdRegKeyNameDisabled
}

$sw.Stop()

Write-Verbose "Excution time $($sw.ElapsedMilliseconds) ms"


Stop-Transcript
