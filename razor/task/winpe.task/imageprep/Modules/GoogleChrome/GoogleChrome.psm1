Set-StrictMode -Version 2.0
$ErrorActionPreference = 'STOP'

$ChromeStandaloneSetupUrl = 'https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7BAA97E3F8-6D9A-45E2-4604-E75F45AFAF22%7D%26lang%3Den%26browser%3D3%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26installdataindex%3Ddefaultbrowser/update2/installers/ChromeSetup.exe'

function Install-GoogleChrome {
  [CmdletBinding()] Param(
    [String] $InstallerUrl = $ChromeStandaloneSetupUrl,
    [String] $InstallerExecutable
  )

  $ChromeSetup = (Join-Path $Env:TEMP 'ChromeStandaloneSetup.exe')

  if ( $InstallerExecutable ) {
    cp $InstallerExecutable $ChromeSetup -Verbose:$VerbosePreference
  }

  if ( $InstallerUrl ) { 
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($InstallerUrl, $ChromeSetup)
  }
  
  if ( -not(Test-Path $ChromeSetup) ) {
    throw "Chrome Installer ($ChromeSetup) does not exist."
  }

  $process = Start-Process -FilePath $ChromeSetup -ArgumentList @('/install') -PassThru -Wait -NoNewWindow
  if ( -not( $Process ) ) {
    throw "Error executing $process for $ChromeSetup"
  }
  else {
    $Process | Select *path*,*id,*name,*title* | %{ Write-Verbose "  $_" }
    Write-Verbose "  Waiting for process to end"
    $process | Wait-Process
  }

  rm $ChromeSetup -Force -ea 0

  Write-Verbose "  ExitCode : $($Process.ExitCode)"
  return $Process.ExitCode

}
