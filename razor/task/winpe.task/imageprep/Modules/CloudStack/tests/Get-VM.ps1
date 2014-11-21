$VerbosePreferece = "CONTINUE"

# CS 3.0.6
# $s = New-CloudStackSession  -ApiEndPoint  'http://camautocs0.eng.citrite.net:8080/client/api' `
#                 -ApiKey       'HorNuo2tQEAoqg9gGfeDzEafwxXJLCmPBAIPT5PWMuFPjYFQkX32Fi8LEdBBnSDHtvMnSOuhvbw6z9Inir5dTQ' `
#                 -SecretKey    'hgR095hRt9g6CyzvbcnUvsxab8GQtBUiI6sd8GThAGT0Ht7T5tVaJUeY7rj3JnYVcO1_ggHtt8ef0-Y5ezerlQ'

# CS 4.2
$s = New-CloudStackSession  -ApiEndPoint  'http://cloud1.cam.onelab.citrix.com:8080/client/api' `
                -ApiKey     'SMThWzncztxWyH2HaMUI5BexBVyPjeIGf2P0LxoSEd0gQ-PI7z2cGrlWRV7k2W7wsIuyJ4rCK_f1kHV4ZfbRgg' `
                -SecretKey  'qD-71vpw3lzdKD4pjj9mDP2GwuPIkSPAR6gvK0qddXFidv6U4172Fz3ShEgl_vEVWcrXPanURLavmuMBMp98GQ' `
                -Verbose

Set-CloudStackSession -Session $s
return

Write-Host -Fore Cyan "Invoke-CloudStackApiCommand - listUsers"
CloudStack\Invoke-CloudStackApiCommand -Command 'listUsers' -Verbose:$VerbosePreference

Write-Host -Fore Cyan "Invoke-CloudStackApiCommand - listCapabilities"
CloudStack\Invoke-CloudStackApiCommand -Command 'listCapabilities' -Verbose:$VerbosePreference

CloudStack\Invoke-CloudStackApiCommand -Command 'listAccounts' -Verbose:$VerbosePreference -ea 0
Write-Host -Fore Cyan "Invoke-CloudStackApiCommand - listApis"

CloudStack\Invoke-CloudStackApiCommand -Command 'listApis' -Verbose:$VerbosePreference -ea 0
Write-Host -Fore Cyan "Invoke-CloudStackApiCommand - listVirtualMachines"

CloudStack\Invoke-CloudStackApiCommand -Command 'listVirtualMachines' -Verbose:$VerbosePreference
CloudStack\Invoke-CloudStackApiCommand -Command 'listNics' -Options @{ 'virtualmachineid' = '7f9a4193-7b3a-44b5-a995-ef48eb51ba28' } -Verbose:$VerbosePreference
return 
Write-Host -Fore Cyan "Invoke-CloudStackApiCommand - listOsCategories"
CloudStack\Invoke-CloudStackApiCommand -Command 'listOsCategories' -Verbose:$VerbosePreference -ea 0
Write-Host -Fore Cyan "Invoke-CloudStackApiCommand - listOsTypes"
CloudStack\Invoke-CloudStackApiCommand -Command 'listOsTypes' -Verbose:$VerbosePreference -ea 0
$n2 = CloudStack\Invoke-CloudStackApiCommand -Command 'listVirtualMachines' -Session $s -Verbose:$VerbosePreference
return 
if ( $n2.Count -ne $n1.Count ) {
  Throw "Number of templates wrong - listVirtualMachines"
}

Write-Host -Fore Cyan "Invoke-CloudStackApiCommand - listTemplates"
CloudStack\Invoke-CloudStackApiCommand -Command 'listTemplates' -Verbose:$VerbosePreference -ea 0
Write-Host -Fore Cyan "Invoke-CloudStackApiCommand - listTemplates with Options"
CloudStack\Invoke-CloudStackApiCommand -Command 'listTemplates' -Options @{'templatefilter'='all'} -Verbose:$VerbosePreference
Write-Host -Fore Cyan "Invoke-CloudStackApiCommand - listRegions"
CloudStack\Invoke-CloudStackApiCommand -Command 'listRegions' -Verbose:$VerbosePreference -ea 0
Write-Host -Fore Cyan "Invoke-CloudStackApiCommand - listNetworkOfferings"
CloudStack\Invoke-CloudStackApiCommand -Command 'listNetworkOfferings' -Verbose:$VerbosePreference -ea 0

Write-Host -Fore Cyan "Template All"
CloudStack\Get-Template -Verbose:$VerbosePreference -TemplateFilter 'all'
Write-Host -Fore Cyan "Templates Self"
CloudStack\Get-Template -Verbose:$VerbosePreference -TemplateFilter 'all'
return
Write-Host -Fore Cyan "Zone"
CloudStack\Get-Zone -Verbose:$VerbosePreference
Write-Host -Fore Cyan "Network"
CloudStack\Get-Network -Verbose:$VerbosePreference
Write-Host -Fore Cyan "VM"
CloudStack\Get-VM -Verbose:$VerbosePreference
Write-Host -Fore Cyan "Offering"
CloudStack\Get-Offering -Verbose:$VerbosePreference

