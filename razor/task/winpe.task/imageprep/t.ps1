
function Select-FromList {
  [CmdletBinding()]
  Param(
    [Object[]]$ObjectArray,
    [String]$Prompt = "Enter selection"
  )

  $c=1
  $ObjectArray | %{
    $MenuItem = New-Object PSObject
    $MenuItem | Add-Member NoteProperty Idx   $c -PassThru |
                Add-Member NoteProperty Item  $_
    $c++
    $MenuItem
  } | ft -auto

  function Get-MySelection {
    $SIdx = Read-Host "$Prompt [$($ObjectArray.Length - 1)] : "

    if ( -not( $SIdx ) ) {
      return ($ObjectArray.Length - 1)
    }

    if ( ($SIdx -lt 0) -or ($SIdx -gt ($ObjectArray.Length - 1)) ) {
      return $ObjectArray[$SIdx]
    }
    else {
      return $False
    }
  }

    
  while ( -not($Idx = Get-MySelection) ) {
    ;
  }

  return $ObjectArray[$Idx]
}
