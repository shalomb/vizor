# PowerShell

Set-StrictMode -Version 2.0

function ConvertFrom-Base64 {
  [CmdletBinding()] Param(
    [String] $Base64
  )
  [System.Text.Encoding]::UTF8.GetString( [System.Convert]::FromBase64String($Base64) )
}

function ConvertTo-Base64 {
  [CmdletBinding()] Param(
    [String] $String
  )
  [System.Convert]::ToBase64String( [System.Text.Encoding]::UTF8.GetBytes($String) )
}

function Invoke-UserData {
  [CmdletBinding()] Param(
    [String] $Base64,
    [String] $String
  )

  if ( $Base64 ) {
    $String = ConvertFrom-Base64 $Base64
  }

  if ( $String ) {
    Switch ( $String.GetType() ) {
      'String'      { iex $String      }
      'ScriptBlock' { $String.Invoke() }
    }
  }
  else {
    Throw "No UserData supplied."
  }
}

