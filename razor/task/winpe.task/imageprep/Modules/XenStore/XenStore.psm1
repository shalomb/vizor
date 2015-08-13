#PowerShell 2.0

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'STOP'

$Script:Session = $Null

function New-XenStoreSession {
  [CmdletBinding()] Param(
    [String]$SessionName = [String][Guid]::NewGuid()
  )

  $CXSB = Get-WMIObject -n root\wmi -cl CitrixXenStoreBase

  $SessionObj = $CXSB.AddSession($SessionName)
  $SessionId = $SessionObj.SessionId

  $Script:Session = Get-WMIObject -n root\wmi -q "SELECT * FROM CitrixXenStoreSession WHERE SessionId=$SessionId"

  $Script:Session

<#
.SYNOPSIS
Create a new sticky XenStore WMI Session.
#>
}

function Get-XenStoreKeys {
  [CmdletBinding()] Param(
    [String] $Key
  )

  try {
    if ( ($Children = $Script:Session.GetChildren($Key)) ) {
      [String[]]$Keys = @()

      $Keys += $Children.Children.ChildNodes | ?{ $_ } | %{
        Get-XenStoreKeys -Key $_ | %{ $_ }
        [String]$_
      } | Sort

      # If a key does not have a full match (left-most) against the other
      # keys being considered, then it is a parent. If so, attach all
      # other keys as children to it and create a tree in the process.
      $Return = @()
      for( $i=0; $i -lt $Keys.Count; $i++ ) {
        $IsParent = $False
        for ( $j=$i+1; $j -lt $Keys.Count; $j++ ) {
          if ( $Keys[$j].IndexOf($Keys[$i]) -eq 0 ) {
            $IsParent = $True
          }
        }
        if ( ! $IsParent ) { $Return+= $Keys[$i] }
      }

      $Return
    }
  } catch {
    Write-Warning "ERROR, $_"
  }

<#
.SYNOPSIS
Enumerate and return an array of the XenStore keys for the current domain.
#>
}

function Get-XenStoreValue {
  [CmdletBinding()] Param(
    [String] $Key = ('/local/domain/{0}' -f (Get-XenStoreValue 'domid'))
  )

  try {
    if ( ($Children = $Script:Session.GetChildren($Key)) ) {
      $PSObject = New-Object PSObject
      $c=0; Get-XenStoreKeys -Key $Key | ?{$_} | %{
        $PSObject | Add-Member NoteProperty $_ (Get-XenStoreValue -Key $_)
        $c++
      }
      if ( $c -gt 0 ) { return $PSObject }
    }
  } catch {
    Write-Warning "ERROR, $_"
  }

  if ( $GV = $Script:Session.GetValue($Key) ) {
    return $GV.Value
  }

<#
.SYNOPSIS
Return the XenStore Key/Value collection for the current domain.

.DESCRIPTION
To discover the various XenStore data paths, refer to
* http://xenbits.xen.org/docs/unstable/misc/xenstore-paths.html
* http://wiki.christophchamp.com/index.php/Xenstore

.EXAMPLE
Get-XenStoreValue -Key domid

.EXAMPLE
#>
}

Set-Alias Get-XenStore Get-XenStoreValue

$Script:Session = New-XenStoreSession

Export-ModuleMember -Function *-* -Alias *-*

# Notes
#   CloudInit Config Drive
#   CloudInit NoCloud vfat/iso9660
#   VMWare vmrun guestVar
#   Hyper-V Key/Value Data Exchange
