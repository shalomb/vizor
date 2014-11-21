# Script Module SystemUtils/SystemUtils.psm1


Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0


try {
  Add-PSSnapin XenServerPSSnapIn -ea 0
} catch {}


function New-XenServerConnection {
  [CmdletBinding()]
  Param(
    $Url,
    $UserName = 'root',
    $Password
  )
  Connect-XenServer -Url $Url -UserName $UserName -Password $Password
}


function Get-Templates {
  [CmdletBinding()]
  Param()
  Get-XenServer:VM | ?{ 
    ($_.is_a_template -eq 'true') -and ($_.VBDs) -and ($_.snapshot_of.opaque_ref -imatch 'NULL') -and ($_.name_label)
  } | %{
    if ($GuestMetrics = Get-XenServer:VM.GuestMetrics -VM $_.UUID) {
      $out = New-Object PSObject
      $out | Add-Member NoteProperty Name             ($_.name_label)
      $out | Add-Member NoteProperty UUID             ($_.uuid)
      $BaseTemplateName = 'UNKNOWN';
      try { $BaseTemplateName = ($_.other_config.base_template_name) } catch {}
      $out | Add-Member NoteProperty BaseTemplate     $BaseTemplateName
      $out | Add-Member NoteProperty VCPUs            ($_.VCPUs_max)
      $out | Add-Member NoteProperty Memory           ($_.memory_static_max)
      $out | Add-Member NoteProperty OSName           ($GuestMetrics.os_version.name -split '\|')[0]
      if ($out.OSName -imatch '\bServer\b') {
        $out | Add-Member NoteProperty ServerOS $True
        $out | Add-Member NoteProperty ClientOS $False
      } 
      else {
        $out | Add-Member NoteProperty ServerOS $False
        $out | Add-Member NoteProperty ClientOS $True
      } 
      $out | Add-Member NoteProperty OSVersion        ([System.Version](($GuestMetrics.os_version)["major","minor"] -join ".")).ToString()
      $SPVersion = [System.Version]"0.0"
      try {
        $SPVersion = ([System.Version](($GuestMetrics.os_version)["spmajor","spminor"] -join ".")).ToString()
      } catch {}
      $out | Add-Member NoteProperty SPVersion        $SPVersion
      $out | Add-Member NoteProperty PVDriversVersion ([System.Version](($GuestMetrics.PV_drivers_version)["major","minor","micro","build"] -join ".")).ToString()
      
      Write-Output $out
    }
  }
}


Get-Networks {
  ;
}

# vim:sw=2:ts=2:et:foldexpr=getline(v\:lnum)=~'^\s*$'&&getline(v\:lnum-1)=~'^\s*$'&&getline(v\:lnum+1)=~'\S'?'<1'\:1:fdm=expr:filetype=ps1:ff=dos:fenc=ASCII

