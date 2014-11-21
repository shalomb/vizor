#
# Copyright (c) Citrix Systems, Inc. All Rights Reserved.
#

Set-StrictMode -Version 2.0

$ErrorActionPreference = "STOP"
$DebugPreference = "Continue"

function Write-MessageToStream {
<#
.SYNOPSIS
Write messages to a named stream.

.NOTES
Care to be taken, Write-MessageToStream does not honour the
preference variables (under variable:\*Preference*)
and introduce output on streams that the user does not necessarily want.
#>
  [CmdletBinding()]
  Param(  [Alias("Message")]  [PSObject]        $OutputMessage,
          [Alias("Stream")]   [System.String]   $OutputStream = "host",
          [Alias("Force")]    [Switch]          $ForceOutput = $False
      )

  if ($OutputStream -ne $Null) {
    Write-Verbose "Writing '$OutputMessage' on '$OutputStream'"
    switch ( $OutputStream.ToLower() ) {
      'host'      { Write-Host      $OutputMessage }
      'debug'     { Write-Debug     $OutputMessage }
      'error'     { Write-Error     $OutputMessage }
      'progress'  { Write-Progress  $OutputMessage }
      'verbose'   { Write-Verbose   $OutputMessage }
      'warning'   { Write-Warning   $OutputMessage }
      *           { throw "Invalid stream: '$OutputStream'" }
    }
  }
  else {
    $Host.UI.WriteLine( $OutputMessage )
  }
}

function Trace-CallStack {
<#
.SYNOPSIS
Generate a call stack trace (like in python).
#>


  [CmdletBinding()] Param(  
      [Alias("Message")]      [PSObject]      $TraceMessage,
      [Alias("Property")]     [System.Array]  $PSCallStackProperties = @("Location", "Command", "Arguments"),
      [Alias("Stream")]       [System.String] $OutputStream   = "Debug",
      [Alias("FramesToSkip")] [System.Int32]  $SkipFrames     = 1,
      [Alias("Terse")]        [Switch]        $NoVerbose      = $False,
      [Alias("Force")]        [Switch]        $ForceOutput    = $False,
      [Alias("Decorate")]     [Switch]        $UseDecorations = $False
  )

  if ( ( $TraceCallStackPreference -imatch "SilentlyContinue" ) ) { return }
  if ( ( $TraceCallStackPreference -imatch "^re:" ) ) { 
    $_SelectFunctionRegex = [string](([regex]"re:(.*)").Matches($TraceCallStackPreference)).Groups[1]
  }

  $_savedStreamPreferenceGUID = [string][guid]::NewGuid()
  New-Item -Path Variable:\$_savedStreamPreferenceGUID   -Value (ls Variable:\${OutputStream}Preference).Value | Out-Null
  Set-Item -Path Variable:\"${OutputStream}Preference"  -Value "Continue" | Out-Null


  $_PSCallStack         = (Get-PSCallStack)
  $_CallerFrame         = ($_PSCallStack)[1]
  $_TraceBackLeaderMsg  = "TraceBack (most recent call last): "

  Write-Host "Called from $_CallerFrame"
  Write-Host " `$TraceCallStackPreference = $TraceCallStackPreference"
  if ( $_SelectFunctionRegex -ne $Null ) {
    if ( -not( (([regex]$_SelectFunctionRegex).Match($_CallerFrame.Command)).Success ) ) {
      return
    }
  }

  if ($TraceMessage -eq $Null) { $TraceMessage = $_CallerFrame.InvocationInfo.Line -replace "`n|^\s+", "" }
  
  if ($UseDecorations) { Write-MessageToStream -Stream $OutputStream -OutputMessage ("-" * 40) }
  if ($NoVerbose) {
    $TraceMessage = ($PSCallStackProperties | %{ $_CallerFrame.($_) }) -join " : "
    Write-MessageToStream -Stream $OutputStream -OutputMessage "$_TraceBackLeaderMsg $TraceMessage"
    $SkipFrames++
  } 
  else {
    Write-MessageToStream -Stream $OutputStream -OutputMessage "$_TraceBackLeaderMsg $TraceMessage"

    $_PSCallStack |
      Select-Object -Skip $SkipFrames |
      %{  $frame = $_
          Write-MessageToStream -Stream $OutputStream `
            -OutputMessage ("  " + ( ($PSCallStackProperties | %{ $frame.($_) }) -join " : "))
      }
  }
  if ($UseDecorations) { Write-MessageToStream -Stream $OutputStream -OutputMessage ("-" * 40) }

  Set-Item -Path Variable:\"${OutputStream}Preference"  -Value (ls Variable:\$_savedStreamPreferenceGUID).Value  | Out-Null
  #Write-Host " Return = $((ls Variable:\${OutputStream}Preference).Value)"
}

if ( -not( Test-Path Variable:\TraceCallStackPreference ) ) {
  New-Item -Path Variable:\TraceCallStackPreference -Value "SilentlyContinue"
}

Export-ModuleMember Show-*,Write-*,Trace-*

