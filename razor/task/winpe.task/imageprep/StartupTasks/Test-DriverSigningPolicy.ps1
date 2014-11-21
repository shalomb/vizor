Set-StrictMode -Version 2.0

$PolicyDefinitions = @{
  0 = "Silently succeed";
  1 = "Warn but allow installation";
  2 = "Do not allow installation";
};

$CurrentPolicy = [Int]((Get-ItemProperty -Path "HKLM:\Software\Microsoft\Driver Signing" -Name Policy).Policy[0])

if ($CurrentPolicy) {
  Write-Host "Current Driver Signing Policy Set to : ($CurrentPolicy), $($PolicyDefinitions[$CurrentPolicy])"
  if ( $CurrentPolicy -eq 0 ) {
    Write-Error "Current driver signing policy does not verify driver signatures."
  }
}
else {
  Write-Error "Unable to determine the current driver signing policy."
}
