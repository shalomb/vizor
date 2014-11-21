Set-StrictMode -Version 2.0
$ErrorActionPreference = 'STOP'

$FirefoxStandaloneSetupUrl = 'https://download.mozilla.org/?product=firefox-30.0-SSL&os=win'
$FirefoxStandaloneSetupUrl = 'https://download.mozilla.org/?os=win'

function Install-MozillaFirefox {
  [CmdletBinding()] Param(
    [String] $InstallerUrl = $FirefoxStandaloneSetupUrl,
    [String] $InstallerExecutable,
    [String] $Language = $host.CurrentCulture.Name,
    [String] $Version = 'stub'
  )

  $FirefoxSetup = (Join-Path $Env:TEMP 'FirefoxSetup.exe')

  if ( $InstallerExecutable ) {
    cp $InstallerExecutable $FirefoxSetup -Verbose:$VerbosePreference
  }

  if ( $InstallerUrl ) { 
    if ( $Language ) {
      $InstallerUrl = "{0}&lang={1}" -f $InstallerUrl,$Language
    }
    if ( $Version ) {
      $InstallerUrl = "{0}&product=firefox-{1}" -f $InstallerUrl,$Version
    }
    Write-Verbose "Downloading $InstallerUrl to $FirefoxSetup"
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($InstallerUrl, $FirefoxSetup)
  }
  
  if ( -not(Test-Path $FirefoxSetup) ) {
    throw "Firefox Installer ($FirefoxSetup) does not exist."
  }

  $process = Start-Process -FilePath $FirefoxSetup -ArgumentList @('-ms') -PassThru -Wait -NoNewWindow
  if ( -not( $Process ) ) {
    throw "Error executing $process for $FirefoxSetup"
  }
  else {
    $Process | Select *path*,*id,*name,*title* | %{ Write-Verbose "  $_" }
    Write-Verbose "  Waiting for process to end"
    $process | Wait-Process
  }

  rm $FirefoxSetup -Force -ea 0

  Write-Verbose "  ExitCode : $($Process.ExitCode)"
  return $Process.ExitCode

}
