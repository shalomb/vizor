# Script Module VMGuestTools/VMGuestTools.psm1


Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0



function Get-VMType {
  [CmdletBinding()]
  Param()

  $VMType = New-Object PSObject
  if (XenTools\Test-IsXenVM) {
    $VMType | Add-Member NoteProperty VMType "Xen"
  }
  elseif (VMWareTools\Test-IsVMWareVM) {
    $VMType | Add-Member NoteProperty VMType "VMWare"
  }
  elseif (HyperVIC\Test-IsHypervVM) {
    $VMType | Add-Member NoteProperty VMType "HyperV"
  }

  $VMType
}


function Get-VMGuestToolsStatus {
  [CmdletBinding()]
  Param()

  Write-Verbose "  Retrieving VM Guest Tools InstallStatus for VMType : $(Get-VMType).VMType"
  $Report = New-Object PSObject
  Switch -Regex ( (Get-VMType).VMType ) {
    'Xen' {
      $Report | Add-Member NoteProperty Type          'Xen'
      $Report | Add-Member NoteProperty Installed     (Test-XenToolsInstallation -ea 0)
      $Report | Add-Member NoteProperty InstallStatus ([Boolean]((Get-XenPVInstallStatus).InstallStatus))
      $Report | Add-Member NoteProperty Version       (Get-XenToolsVersion -ea 0)
    }
    'VMWare' {
      $Report | Add-Member NoteProperty Type          'VMWare'
      $Report | Add-Member NoteProperty Installed     (Test-VMWareToolsInstallation -ea 0)
      $Report | Add-Member NoteProperty InstallStatus (Test-VMWareToolsInstallation -ea 0)
      $Report | Add-Member NoteProperty Version       (Get-VMWareToolsVersion -ea 0)
    }
    'HyperV' {
      $Report | Add-Member NoteProperty Type          'HyperV'
      $Report | Add-Member NoteProperty Installed     (Test-HyperVToolsInstallation -ea 0)
      $Report | Add-Member NoteProperty InstallStatus (Test-HyperVToolsInstallation -ea 0)
      $Report | Add-Member NoteProperty Version       (Get-HyperVToolsVersion -ea 0);;;
    }
  }
  $Report
}


function Install-VMGuestTools {
  [CmdletBinding()]
  Param(
    [Switch] $NoRestart
  )

  Switch -Regex ( (Get-VMType).VMType ) {
    'Xen'     {
      Write-Verbose "Detected as being a Xen VM"
      XenTools\Install-XenTools -NoRestart:$NoRestart -Verbose:$VerbosePreference
      return $?
    }
    'VMWare'  {
      Write-Verbose "Detected as being a VMWare VM"
      VMWareTools\Install-VMWareTools -NoRestart:$NoRestart -Verbose:$VerbosePreference
      return $?
    }
    'HyperV'  {
      Write-Verbose "Detected as being a Hyper-V VM ($VerbosePreference)"
      HyperVIC\Install-HyperVIntegrationServices -NoRestart:$NoRestart -Verbose:$VerbosePreference
      return $?
    }
    .* {
      Write-Warning "VMType is unknown"
      return $?
    }
  }
}


# vim:sw=2:ts=2:et:foldexpr=getline(v\:lnum)=~'^\s*$'&&getline(v\:lnum-1)=~'^\s*$'&&getline(v\:lnum+1)=~'\S'?'<1'\:1:fdm=expr:filetype=ps1:ff=dos:fenc=ASCII

