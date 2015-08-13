# PowerShell

$Env:PSModulePath = "${Env:SystemDrive}\ProgramData\firstboot\Modules;${Env:PSModulePath}"

Import-Module XenStore
Import-Module UserData

if ( $b64 = Get-XenStore -key 'vm-data/base64_boot_params' ) {
  try {
    # test whether state enum has already been created,
    # if not create it and set default state to failed
    # add here so this script can be run standalone
    $testState = [State]::Failed
  }
  catch
  {
    Add-Type -TypeDefinition @"
    public enum State {
      Run,
      Disabled,
      Failed,
      TimedOut
    }
"@
  }

  try {
    Invoke-UserData -Base64 $b64
    $global:state = [State]::Disabled
  }
  catch {
    Write-Warning "Invoking userdata failed [$_]."
    $global:state = [State]::Failed
  }
}

