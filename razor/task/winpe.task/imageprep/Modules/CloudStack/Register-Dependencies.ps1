# PowerShell

Set-StrictMode -Version 2
$ErrorActionPreference = "STOP"

"CloudStackClient" | %{
  Import-Module -Name $_
}
