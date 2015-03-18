# PowerShell

Set-StrictMode -Version 2.0

function Resolve-Expression {
  [CmdletBinding()] Param(
    [PSObject] $Expression
  )

  Write-Verbose "Resolve-Expression. $Expression"

  if ( $Expression -eq $Null ) { return $Null } # No Tests or Assertions yet, the assertion logic depends on this

  Switch ( $Type = $Expression.GetType().Name ) {
    'ScriptBlock' { $Expression.Invoke() }
    'String'      {
      if ( [String]::IsNullOrEmpty($Expression) ) { $False } else { Invoke-Expression $Expression }
    }
    default       { $Expression }
  }
<#
.SYNOPSIS
  Resolve-Expression - Reduce an expression by attempting to invoke it.
#>
}


function Assert-Condition {
  [CmdletBinding()]
  Param(
    [Parameter(ParameterSetName="p1", Position=0, Mandatory=$True,  HelpMessage="Enter an expression to test.")]
      [PSObject] $Expression,
    [Parameter(ParameterSetName="p1", Position=1, Mandatory=$False, HelpMessage="Enter an expression to execute on test failure.")]
      [PSObject] $FailExpression,
    [Parameter(ParameterSetName="p1", Position=2)]
      [Switch]   $IsFatal
  )

  $ResolvedExpression = Resolve-Expression $Expression

  $ExceptionMessage = $Null
  switch ( [boolean] $ResolvedExpression ) {
    $False {
      try {
        Switch ($FailExpression.GetType().Name ) {
          'ScriptBlock' {
            try {
              $FailExpression.Invoke()
            } catch {
              Throw "Failed processing FailExpression : $_"
            }
          }
          'String' { Throw "Assertion failed. $FailExpression" }
          default  { $FailExpression }
        }
      }
      catch [exception] {
        $ExceptionMessge = $_
      }
      finally {
        if ( $ExceptionMessage ) {
          $FailExpression +=
            " Additionally, An exception '$ExceptionMessage' was encountered " +
            " when running FailExpression '$FailExpression'"
        }
        if ( $IsFatal ) {
          Trace-CallStack "$FailExpression"
        }
      }
      return $False
    }
    $True { return $True }
  }
<#
.SYNOPSIS
  Assert-Condition - Assert the truth of a simple expression
#>
}


function Test-IsNull     { [CmdletBinding()] Param( [PSObject] $Expression ) (Resolve-Expression $Expression) -eq $Null }
function Test-IsNotNull  { [CmdletBinding()] Param( [PSObject] $Expression ) (Resolve-Expression $Expression) -ne $Null }
function Test-IsTrue     { [CmdletBinding()] Param( [PSObject] $Expression ) (Resolve-Expression $Expression)     }
function Test-IsNotTrue  { [CmdletBinding()] Param( [PSObject] $Expression ) -not(Resolve-Expression $Expression) }
function Test-IsFalse    { [CmdletBinding()] Param( [PSObject] $Expression ) (Resolve-Expression $Expression) -eq $False }
function Test-IsNotFalse { [CmdletBinding()] Param( [PSObject] $Expression ) (Resolve-Expression $Expression) -ne $False }


function Assert-IsNull {
  [CmdletBinding()] Param(
    [PSObject] $Expression,
    [PSObject] $FailExpression = "Assertion (isNull) failed for '$Expression'.",
    [Switch]   $IsFatal = $True
  )
  Assert-Condition -Expression ((Resolve-Expression $Expression) -eq $Null) -FailExpression $FailExpression -IsFatal:$IsFatal
}


function Assert-IsNotNull {
  [CmdletBinding()] Param(
    [PSObject] $Expression,
    [PSObject] $FailExpression = "Assertion (isNotNull) failed for '$Expression'",
    [Switch]   $IsFatal = $True
  )
  Assert-Condition -Expression ((Resolve-Expression $Expression) -ne $Null) -FailExpression $FailExpression -IsFatal:$IsFatal
}


function Assert-IsTrue {
  [CmdletBinding()] Param(
    [PSObject] $Expression,
    [PSObject] $FailExpression = "Assertion (isTrue) failed for '$Expression'.",
    [Switch]   $IsFatal = $True
  )
  Assert-Condition -Expression ([Boolean](Resolve-Expression $Expression) -eq $True) -FailExpression $FailExpression -IsFatal:$IsFatal
}
sal assert Assert-IsTrue

function Assert-IsNotTrue {
  [CmdletBinding()] Param(
    [PSObject] $Expression,
    [PSObject] $FailExpression = "Assertion (isNotTrue) failed for '$Expression'.",
    [Switch]   $IsFatal = $True
  )
  Assert-Condition -Expression ([Boolean](Resolve-Expression $Expression) -ne $True) -FailExpression $FailExpression -IsFatal:$IsFatal
}


function Assert-IsFalse {
  [CmdletBinding()] Param(
    [PSObject] $Expression,
    [PSObject] $FailExpression = "Assertion (isFalse) failed for '$Expression'.",
    [Switch]   $IsFatal = $True
  )
  Assert-Condition -Expression ([Boolean](Resolve-Expression $Expression) -eq $False) -FailExpression $FailExpression -IsFatal:$IsFatal
}


function Assert-IsNotFalse {
  [CmdletBinding()] Param(
    [PSObject] $Expression,
    [PSObject] $FailExpression = "Assertion (isNotFalse) failed for '$Expression'.",
    [boolean]  $IsFatal = $True
  )
  Assert-Condition -Expression ([Boolean](Resolve-Expression $Expression) -ne $False) -FailExpression $FailExpression -IsFatal:$IsFatal
}

Export-ModuleMember -Alias assert,Test-*,Assert-* -Function *

