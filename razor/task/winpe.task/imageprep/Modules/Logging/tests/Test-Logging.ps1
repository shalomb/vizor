Set-StrictMode -Version 2.0

$ErrorActionPreference="Stop"
$VerbosePreference="Continue"
$DebugPreference="WhatContinue"
$Global:TraceCallStackPreference="FOOBIEs"
# $Global:VerbosePreference="SilentlyContinue"
# $Global:VerbosePreference="Continue"

  $Env:PSModulePath+=";$($PWD.ProviderPath)"
  Write-Verbose "`$Env:PSModulePath=$Env:PSModulePath"
  Write-Verbose "Import-Module PowerShell/Logging"
Import-Module PowerShell/Logging -Force

function baz {
  [CmdletBinding()]
  Param($p)
  Trace-CallStack
}

function bar {
  [CmdletBinding()]
  Param($p)
  Trace-CallStack
  baz($p)
}

function foo {
  [CmdletBinding()]
  Param($p, [Switch]$UseDecorations)
  # Trace-CallStack -Terse
  bar($p)
}

Write-Host      "Baz"
Trace-CallStack "Baz"
baz
Write-Host      "Bar"
Trace-CallStack "Bar"
bar
Write-Host      "Foo"
Trace-CallStack "Foo"
foo "one"
exit

# Test Case - Simple Call
$Tests = @{
  "Simple Function Call" = @{ Test = { baz "Hello World!!" }; Result = ""; };
  "Nested Function Call" = @{ Test = { foo "Hello World!!" }; Result = ""; };
}
# $Tests | fl *

$Tests.Keys | %{
  $Tests[$_]["Result"] = ($Tests[$_]["Test"]).Invoke()
}

$Tests.Keys | %{
  $msg = "{0}  =>  {1}" -f $_, $Tests[$_]["Result"]
  Write-Host $msg
}
