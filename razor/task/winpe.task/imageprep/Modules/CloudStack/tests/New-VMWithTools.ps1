Set-PSDebug -Trace 0
Set-StrictMode -Version 1

$VerbosePreferece = "CONTINUE"

ipmo CloudStack -Verbose
ipmo CloudStackClient -Verbose

$s = New-CloudStackSession `
      -ApiEndPoint  'http://cloud2.cam.onelab.citrix.com:8080/client/api' `
      -ApiKey     'tH4WNU7od2nyYTV9OL5KUI-WQ3tY2clOxS1Xxa0Yzjf5nEFEmtzXbyKLjmsn93A3DhPxwvYErTzKwx-TjBnZwg' `
      -SecretKey  'cufas1pWk2RYzqtEfY9zu9dwQMEnH9JNHBIyUwMhYe4KzzgwigDrsBB1Z7HArj1hHbmithHgFMx4rencJIL0qg' `
      -Verbose


$zoneid = Get-Zone | Select -expand id
$serviceofferingid = Get-ServiceOffering -Options @{ name='m1.xsmall' }
$templateid = Get-Template -TemplateFilter 'executable' | ?{ $_.name -ilike 'Win81.*6570'
} | select -expand id

Set-CloudStackSession -Session $s
# CloudStack\Invoke-CloudStackApiCommand -Command 'listUsers' -Verbose:$VerbosePreference

$toolsisos = CloudStack\Invoke-CloudStackApiCommand -Command 'listIsos' -Options @{ isofilter = 'featured'; isready='true'; bootable='false'; }

$toolsisos
exit

$vm = CloudStack\New-VM -ZoneId $zoneid -ServiceOffering $serviceofferingid -Templateid $templateid
$vmid   = $vm.id

$toolsisoid = Switch -Regex ( $vm.hypervisor ) {
  '.*XenServer.*' {
    $toolsisos | ?{ $_.name -imatch 'xs-tools.iso' } | Select -Expand Id
  }
  '.*vmware|esx|esxi.*' {
    $toolsisos | ?{ $_.name -imatch 'vmware-tools.iso' } | Select -Expand Id
  }
  .* {
    Write-Warning "Unknown/Unimplemented hypervisor type '$($vm.hypervisor)' detected for VM '$($vm.name)' ($($vm.id))"
  }
}

$attachiso_job = CloudStack\Invoke-CloudStackApiCommand -Command 'attachIso' -Options @{ id = $toolsisoid; virtualmachineid = $$vm.id }
Get-AsyncResult -JobId $attachiso_job -Synchronous

return


