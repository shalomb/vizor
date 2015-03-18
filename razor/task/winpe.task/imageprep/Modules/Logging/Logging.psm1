Set-StrictMode -Version 2.0


$DebugPreference = "Continue"

function Write-MessageToStream {
  <#
.NOTES
  Care to be taken, Write-MessageToStream does not honour the
  preference variables (under variable:\*Preference*)
  and introduce output on streams that the user does not necessarily want.
.TODO
  Reconsider as Bug??
  #>
  [CmdletBinding()]
  Param(
    [Alias("OutputMessage")]  [PSObject]        $Message,
    [ValidateSet('host','debug','error','progress','verbose','warning')] [Alias("OutputStream")]
      $Stream = "host"
  )
  if ($Stream -ne $Null) {
    Write-Verbose "Writing '$Message' on '$Stream'"
    switch ( $Stream.ToLower() ) {
      'host'      { Write-Host      $Message }
      'debug'     { Write-Debug     $Message }
      'error'     { $Host.UI.WriteErrorLine( $Message); [Console]::Error.Flush(); }
      'progress'  { Write-Progress  $Message }
      'verbose'   { Write-Verbose   $Message }
      'warning'   { Write-Warning   $Message }
      default     { throw "Invalid stream: '$Stream'" }
    }
  }
  else {
    $Host.UI.WriteLine( $Message )
  }
}

function Trace-CallStack {
  [CmdletBinding()]
  Param(
    [Alias("Message")]          [PSObject]      $TraceMessage,
    [Alias("OutputStream")]     [System.String] $Stream   = "Error",
    [Alias("Property")]         [System.Array]  $PSCallStackProperties = @("Location", "Command", "Arguments"),
    [Alias("FramesToSkip")]     [System.Int32]  $SkipFrames     = 1,
    [Alias("NoVerbose")]        [Switch]        $Terse    = $False,
    [Alias("UseDecoratations")] [Switch]        $Decorate = $False
  )

  $PSCallStack         = (Get-PSCallStack)
  $CallerFrame         = ($PSCallStack)[1]
  $TraceBackLeaderMsg  = "TraceBack (most recent call last): "

  if ($TraceMessage -eq $Null) { $TraceMessage = $CallerFrame.InvocationInfo.Line -replace "`n|^\s+", "" }

  if ($Decorate) { Write-MessageToStream -Stream $Stream -Message ("-" * 40) }
  if ($Terse) {
    $TraceMessage = ($PSCallStackProperties | %{ $CallerFrame.($_) }) -join " : "
    Write-MessageToStream -Stream $Stream -Message "$TraceBackLeaderMsg $TraceMessage"
    $SkipFrames++
  }
  else {
    Write-MessageToStream -Stream $Stream -Message "$TraceBackLeaderMsg $TraceMessage"

    $PSCallStack |
      Select-Object -Skip $SkipFrames |
      %{  $frame = $_
          Write-MessageToStream -Stream $Stream `
            -Message ("  " + ( ($PSCallStackProperties | %{ $frame.($_) }) -join " : "))
      }

    if ($Stream -ieq 'error') { Write-Error (($PSCallStackProperties | %{ $PSCallStack[0].($_) }) -join " : ") }
  }
  if ($Decorate) { Write-MessageToStream -Stream $Stream -Message ("-" * 40) }
}

Export-ModuleMember Show-*,Write-*,Trace-*,Throw*

