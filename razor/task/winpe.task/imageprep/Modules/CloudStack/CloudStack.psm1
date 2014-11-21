# Powershell


Set-StrictMode -Version 2.0
$ErrorActionPreference = "STOP"     # TODO: Remove when stable


# Module Globals

# Hold the object containing the 
#   ApiEndPoint, ApiKey, SecretKey properties
[PSObject] $Script:CSSession = $Null 

# Hold the object containing the API schema returned
# from the listApis CloudStack API Call
[PSObject] $Script:ApiSchema = $Null 


function New-CloudStackSession {
  Param(
    [Parameter(ParameterSetName='default',Mandatory=$True)]  
    [ValidateNotNullOrEmpty()]
    [Alias("ApiUrl")]
      [String] $ApiEndPoint,
    [Parameter(ParameterSetName='default',Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
      [String] $ApiKey,
    [Parameter(ParameterSetName='default',Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
      [String] $SecretKey,
    [Parameter(ParameterSetName='readcfg',Mandatory=$False)]
    [ValidateNotNullOrEmpty()]
      [String] $SettingsFile,
    [Parameter(ParameterSetName='default',Mandatory=$False)] 
    [Parameter(ParameterSetName='readcfg',Mandatory=$False)] 
    [ValidateNotNullOrEmpty()]
      [Boolean] $NoTest,
    [Parameter(ParameterSetName='default',Mandatory=$False)] 
    [ValidateNotNullOrEmpty()]
      [Boolean] $NoWrite
  )

  if ( $psboundparameters.keys -contains 'SettingsFile') {
    if ( -not($CloudStack = Import-CliXml -Path $SettingsFile) ) {
      Throw "Unable to read session information from SettingsFile '$SettingsFile'; $_"
    }
  }
  else {
    $CloudStack = New-Object PSObject
    $CloudStack | Add-Member NoteProperty ApiEndPoint $ApiEndPoint
    $CloudStack | Add-Member NoteProperty ApiKey      $ApiKey
    $CloudStack | Add-Member NoteProperty SecretKey   $SecretKey
  }

  if ( $NoTest ) {
    Write-Verbose "Skipping Connectivity Test."
  } 
  else {
    try {
      # Test connectivity to the management server
      $Capabilities = Invoke-CloudStackApiCommand -Session $CloudStack `
                        -Command 'listCapabilities'
      $Capabilities | Get-Member -MemberType Property | %{
        $CloudStack | 
          Add-Member NoteProperty $_.Name $Capabilities.($_.Name)
      }
    } catch {
      Write-Error "Exception while fetching zone capabilities in API connectivity test for CloudStack APIEndPoint '$ApiEndPoint'. $_"
    }
  }
  
  $Script:CSSession = $CloudStack

  return $cloudStack

<#
.SYNOPSIS
Create a new CloudStack default session and return a session object.

.DESCRIPTION
Create a new CloudStack default session and return a session object.

.PARAMETER  ApiEndPoint
The API URL representing the API EndPoint for the CloudStack Management Server.

This is typically of the form http://cloudstack.example.com:8080/client/api

.PARAMETER ApiKey
The API Key for the user account within the CloudStack domain.

.PARAMETER SecretKey
The Secret Key for the user account within the CloudStack domain.

.PARAMETER SettingsFile
Currently not implemented.

.PARAMETER NoTest
Currently not implemented.

.PARAMETER NoWrite
Currently not implemented.
#>
}

function Set-CloudStackSession {
  [CmdletBinding()]
  Param(
    [Parameter(
      Mandatory=$True,
      ValueFromPipeLine=$True,
      ValueFromPipelineByPropertyName=$True
    )] 
    [Alias('Credentials')]
    [PSObject] $Session = $Script:CSSession
  )
  try {
    if (
      $Session.ApiEndPoint  -and `
      $Session.ApiKey       -and `
      $Session.SecretKey    
    ) {
      $Script:CSSession = $Session
    }
  } catch {
    Throw "Unable to set CloudStackSession variable : $_"
  }
<#
.SYNOPSIS
Update the default session with the session object passed in.

.DESCRIPTION
Update the default session with the session object passed in.

.PARAMETER Session
The session object is a PSObject and must have the following properties.

  * ApiEndPoint
  * ApiKey
  * SecretKey

#>
}

function Get-CloudStackSession {
  [CmdletBinding()]
  Param()
  if ( Test-Path Variable:\CSSession ) {
    $Script:CSSession
  }
  else {
    Write-Warning "No session variable found."
  }
<#
.SYNOPSIS
Return the default session object used in CloudStack API calls.

.DESCRIPTION
Return the default session object used in CloudStack API calls.

This is not the same as the Session Identifier used in CloudStack
sessions but an Object to hold API end-point and keys used in
API requests to the CloudStack API Service on the Management Server.

#>
}

function Invoke-CloudStackApiCommand {
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory=$True)] [ValidateNotNullOrEmpty()]
      [String]  $Command,
    [Parameter(Mandatory=$False)] [HashTable] $Options = @{},
    [Parameter(Mandatory=$False)] [PSObject]  $Session = $Script:CSSession
  )

  # Set the bound parameters even if not explicity specified by caller.
  $MyInvocation.MyCommand.ParameterSets | ?{
    $_.Name -eq $PSCmdlet.ParameterSetName  # Is this ParameterSetName current
  } | %{ 
    $_.Parameters | %{ $_.Name }            # Get required parameter names
  } | %{
    if ( -not($PSBoundParameters.ContainsKey($_)) ) { # If param is not bound
      if ( Test-Path Variable:\$_ ) {       # Is variable defined
        $PSBoundParameters.Add($_, $(Get-Content Variable:\$_ )) | Out-Null # Bind Var
      }
    }
  }

  Get-CloudStack @PSBoundParameters

<#
.SYNOPSIS
Invoke a CloudStack API Call using the CloudStack REST API.

.DESCRIPTION
Invoke a CloudStack API Call using the CloudStack REST API.

The CloudStack API Documentation Reference provides the listing of
acceptable API Calls.

  * http://cloudstack.apache.org/docs/api/ 

.PARAMETER Options
A Hash Table of options to pass to the listSnapshots API Call.

.PARAMETER Session
An optional session object to control the session used for the API Call.
#>
}

function Get-AsyncJobResult {
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory=$True)]  [String]    $JobId,
      [Parameter(Mandatory=$False)] [Switch]    $Synchronous,
      [Parameter(Mandatory=$False)] [Int32]     $PollInterval = 3,
      [Parameter(Mandatory=$False)] [Int32]     $Timeout = 600,
      [Parameter(Mandatory=$False)] [PSObject]  $Session = $Script:CSSession
    )

  $ScriptBlock = { 
    Invoke-CloudStackApiCommand -Command 'queryAsyncJobResult' `
      -Options @{ 'jobid' = $jobid; } -Session $Session
  }


  $Result = & $ScriptBlock;

  if ( -not($Synchronous) ) { 
    return $Result 
  }
  else {

    $MaxIterations = if ( $Timeout -and $PollInterval ) { $Timeout/$PollInterval } else { 1 }

    $c = 1
    while ( ($Result.JobStatus -eq 0) -and ($c -le $MaxIterations) ) {
      Write-Progress -Activity "Job:$JobId" -Status "Ongoing" -PercentComplete ($c/$MaxIterations)

      Start-Sleep -Seconds $PollInterval

      $c++

      $Result = & $ScriptBlock;
    }

  }

  return $Result
<#
.SYNOPSIS
Request the state of an Async Job.

.DESCRIPTION
Request the state of an Async Job.

Certain CloudStack API calls return a JobId for Asynchronous operations
e.g. deployVirtualMachine. This function allows you to query the state
of those Jobs that are being processed by CloudStack in the background.

Refer to the following documentation for specifics of this API Call.
http://cloudstack.apache.org/docs/api/apidocs-4.2/user/listCapabilities.html

.PARAMETER JobId
The JobId previously returned by an Asynchronous API call 

.PARAMETER PollInterval
The frequency (in seconds) to poll CloudStack for the job object.

.PARAMETER Timeout
The period (in seconds) after which to stop polling CloudStack for the job object.

.PARAMETER Session
An optional session object to control the session used for the API Call
#>
}

function Get-Capability {
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory=$False)] [HashTable] $Options,
    [Parameter(Mandatory=$False)] [PSObject]  $Session = $Script:CSSession
  )
  $PSBoundParameters.Add('Command', 'listCapabilities') | Out-Null
  Invoke-CloudStackApiCommand @PSBoundParameters
<#
.SYNOPSIS
Get CloudStack capabilities using the listCapabilities CloudStack API Call.

.DESCRIPTION
Get CloudStack VMs using the listCapabilities CloudStack API Call.

Refer to the following documentation for specifics of this API Call.
http://cloudstack.apache.org/docs/api/apidocs-4.2/user/listCapabilities.html

.PARAMETER Options
A Hash Table of options to pass to the listCapabilities API Call.

.PARAMETER Session
An optional session object to control the session used for the API Call.
#>
}

function New-VM {
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory=$true)]  [String]    $TemplateId,
      [Parameter(Mandatory=$true)]  [String]    $ZoneId,
      [Parameter(Mandatory=$true)]  [String]    $ServiceOfferingId,
      [Parameter(Mandatory=$false)] [String[]]  $SecurityGroupIds,
      [Parameter(Mandatory=$false)] [String[]]  $NetworkIds,
      [Parameter(Mandatory=$false)] [String]    $DisplayName,
      [Parameter(Mandatory=$false)] [String]    $KeyPair,
      [Parameter(Mandatory=$false)] [String]    $Hostname,
      [Parameter(Mandatory=$false)] [String]    $UserData,
      [Parameter(Mandatory=$False)] [HashTable] $Options = @{},
      [Parameter(Mandatory=$False)] [PSObject]  $Session = $Script:CSSession,
      [Parameter(Mandatory=$False)] [Switch]    $Synchronous
  )

  if ( (-not( $Options )) ) { $Options = @{} }

  $Options.Add('templateid'			  , $TemplateId)
  $Options.Add('zoneid'			      , $zoneid)
  $Options.Add('serviceofferingid', $serviceofferingid)

  if ($DisplayName) { $Options.Add( 'displayname' , $DisplayName ) }
  if ($Hostname)    { $Options.Add( 'name'				, $Hostname    ) }
  if ($KeyPair)     { $Options.Add( 'keypair'		  , $KeyPair     ) }
  if ($UserData)    { $Options.Add( 'userdata'		, $UserData    ) }

  if ($SecurityGroupIds) {  # Basic Zone Assumption
    $Options.Add('securitygroupids', ($SecurityGroupIds | Sort-Object) -join ",")
  }
  elseif ($NetworkIds) {    # Advanced Zone Assumption
    $Options.Add('networkids', ($NetworkIds | Sort-Object) -join ",")
  }
  else { # Must we really warn?
    Write-Warning "No network or security groups specified for Instance."
  }

  try {
    $job = Invoke-CloudStackApiCommand -Command 'deployVirtualMachine' `
              -Options $Options -Session $Session
  } catch {
    Throw "Failed to deploy virtual machine for template '$TemplateId', no job returned : $_"
  }

  Write-Verbose "  JobId ($($Job.jobid)) created for VirtualMachine ($($Job.id))"
  if ( $Synchronous ) {
    Get-AsyncJobResult -Job $Job.jobid -Synchronous:$Synchronous
  }
  else {
    $Job
  }

<#
.SYNOPSIS
Deploy a VirtualMachine Instance via the deployVirtualMachine API Call.

.DESCRIPTION
Deploy a VirtualMachine Instance via the deployVirtualMachine API Call.

Refer to the following documentation for specifics of this API Call.
http://cloudstack.apache.org/docs/api/apidocs-4.2/user/deployVirtualMachine.html

.PARAMETER TemplateId
The template ID for the VM.

.PARAMETER zoneid
The zone for the VM.

.PARAMETER serviceofferingid
The Service offering ID for the VM.

.PARAMETER SecurityGroupIds
The Security Group IDs for the VM.

.PARAMETER NetworkIds
The Security Group IDs for the VM.

.PARAMETER Options
A hashtable of options to use in the deployVirtualMachine API call.
Refer to the CloudStack API Reference for a description of options.

.PARAMETER Session
An optional session object to control the session used for the API Call.

#>
}

function Remove-VM {
  Param(
    [Parameter(Mandatory=$true)]  [String]    $Id,
    [Parameter(Mandatory=$False)] [Switch]    $Synchronous,
    [Parameter(Mandatory=$False)] [HashTable] $Options = @{},
    [Parameter(Mandatory=$False)] [PSObject]  $Session = $Script:CSSession
  )

  if ($Id) {
    $PSBoundParameters.Remove('id') | Out-Null
    $Options.Add('id', $id)
  }

  if ( -not $PSBoundParameters.ContainsKey('Options') ) {
    $PSBoundParameters.Add('Options', $Options) | Out-Null
  }

  if ( $Synchronous ) {
    $PSBoundParameters.Remove('Synchronous') | Out-Null
  }

  try {
    $PSBoundParameters.Add('Command', 'destroyVirtualMachine') | Out-Null
    $Job = Invoke-CloudStackApiCommand @PSBoundParameters
  }
  catch {
    Throw "Failed to destroy virtual machine '$Id' : $_"
  }

  if ( $Synchronous -and $Job ) {
    Get-AsyncJobResult -Job $Job.jobid -Synchronous:$Synchronous
  }
  else {
    $Job
  }

<#
.SYNOPSIS
Destroy a CloudStack VirtualMachine using the destroyVirtualMachine CloudStack API Call.

.DESCRIPTION
Refer to the following documentation for specifics of this API Call.
http://cloudstack.apache.org/docs/api/apidocs-4.2/user/destroyVirtualMachine.html

.PARAMETER Id
The Id of the VirtualMachine

.PARAMETER Synchronous
Cause the API call to wait until the job has finished.

.PARAMETER Options
A Hash Table of options to pass to the destroyVirtualMachine API Call.

.PARAMETER Session
An optional session object to control the session used for the API Call.

#>
}

function Stop-VM {
  Param(
    [Parameter(Mandatory=$true)]  [String]    $Id,
    [Parameter(Mandatory=$False)] [Switch]    $Force,
    [Parameter(Mandatory=$False)] [Switch]    $Synchronous,
    [Parameter(Mandatory=$False)] [HashTable] $Options = @{},
    [Parameter(Mandatory=$False)] [PSObject]  $Session = $Script:CSSession
  )

  if ($Id) {
    $PSBoundParameters.Remove('id') | Out-Null
    $Options.Add('id', $id)
  }

  if ( $Force ) {
    $PSBoundParameters.Remove('Force') | Out-Null
    $Options.Add('forced', $True)
  }

  if ( -not $PSBoundParameters.ContainsKey('Options') ) {
    $PSBoundParameters.Add('Options', $Options) | Out-Null
  }

  if ( $Synchronous ) {
    $PSBoundParameters.Remove('Synchronous') | Out-Null
  }

  try {
    $PSBoundParameters.Add('Command', 'stopVirtualMachine') | Out-Null
    $Job = Invoke-CloudStackApiCommand @PSBoundParameters
  }
  catch {
    Throw "Failed to destroy virtual machine '$Id' : $_"
  }

  if ( $Synchronous -and $Job ) {
    Get-AsyncJobResult -Job $Job.jobid -Synchronous:$Synchronous
  }
  else {
    $Job
  }

<#
.SYNOPSIS
Stop a CloudStack VirtualMachine using the stopVirtualMachine CloudStack API Call.

.DESCRIPTION
Refer to the following documentation for specifics of this API Call.
http://cloudstack.apache.org/docs/api/apidocs-4.2/user/stopVirtualMachine.html

.PARAMETER Id
The Id of the VirtualMachine

.PARAMETER Force
Set the forced option to the stopVirtualMachine call.

.PARAMETER Synchronous
Cause the API call to wait until the job has finished.

.PARAMETER Options
A Hash Table of options to pass to the stopVirtualMachine API Call.

.PARAMETER Session
An optional session object to control the session used for the API Call.

#>
}

function Get-VM {
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory=$False)] [Guid]      $Id,
    [Parameter(Mandatory=$False)] [String]    $Name,
    [Parameter(Mandatory=$False)] [String]    $TemplateId,
    [Parameter(Mandatory=$False)] [HashTable] $Options = @{},
    [Parameter(Mandatory=$False)] [PSObject]  $Session = $Script:CSSession
  )

  if ( $Id )        { 
    $PSBoundParameters.Remove('id') | Out-Null
    $Options.Add('id', $id)
  }
  
  if ( $templateid )  { 
    $PSBoundParameters.Remove('templateid') | Out-Null
    $Options.Add('templateid', $templateid)
  }

  if ( $Name )        { 
    $PSBoundParameters.Remove('name') | Out-Null
    $Options.Add('name', $Name)
  }

  if ( -not $PSBoundParameters.ContainsKey('Options') ) {
    $PSBoundParameters.Add('Options', $Options) | Out-Null
  }

  $PSBoundParameters.Add('Command', 'listVirtualMachines') | Out-Null
  Invoke-CloudStackApiCommand @PSBoundParameters

<#
.SYNOPSIS
Get CloudStack VMs using the listVirtualMachines CloudStack API Call.

.DESCRIPTION
Get CloudStack VMs using the listVirtualMachines CloudStack API Call.

Refer to the following documentation for specifics of this API Call.
http://cloudstack.apache.org/docs/api/apidocs-4.2/user/listVirtualMachines.html

.PARAMETER Id
The Id of the VirtualMachine to select.

.PARAMETER Name
The Name of the VirtualMachine to select.

.PARAMETER TemplateId
The TemplateId of those VirtualMachines instantiated from a particular template.

.PARAMETER Options
A Hash Table of options to pass to the listVirtualMachines API Call.

.PARAMETER Session
An optional session object to control the session used for the API Call.

#>
}

function Get-Zone {
  [CmdLetBinding()]
  Param(
    [PSObject]  $Session = $Script:CSSession,
    [HashTable] $Options
  )

  $PSBoundParameters.Add('Command', 'listZones') | Out-Null
  $PSBoundParameters.Add('Session', $Session) | Out-Null
  Invoke-CloudStackApiCommand @PSBoundParameters
<#
.SYNOPSIS
Get CloudStack Zones using the listZones CloudStack API Call.

.DESCRIPTION
Get CloudStack Zones using the listZones CloudStack API Call.

Refer to the following documentation for specifics of this API Call.
http://cloudstack.apache.org/docs/api/apidocs-4.2/user/listZones.html

.PARAMETER Options
A Hash Table of options to pass to the listVirtualMachines API Call

.PARAMETER Session
An optional session object to control the session used for the API Call
#>
}

function Get-Network {
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory=$False)]  [PSObject]   $Session = $Script:CSSession,
    [Parameter(Mandatory=$False)]  [HashTable]  $Options = @{}
  )
  $PSBoundParameters.Add('Command', 'listNetworks') | Out-Null
  $PSBoundParameters.Add('Session', $Session) | Out-Null
  Invoke-CloudStackApiCommand @PSBoundParameters
<#
.SYNOPSIS
Get CloudStack Networks using the listNetworks CloudStack API Call.

.PARAMETER Options
A Hash Table of options to pass to the listNetworks API Call.

.PARAMETER Session
An optional session object to control the session used for the API Call.

.URL
http://cloudstack.apache.org/docs/api/apidocs-4.2/user/listNetworks.html
#>
}

function Get-Template {
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory=$True)]   [String]     $TemplateFilter,
    [Parameter(Mandatory=$False)]  [PSObject]   $Session = $Script:CSSession,
    [Parameter(Mandatory=$False)]  [HashTable]  $Options = @{}
  )
  $Options.Add('templatefilter', $TemplateFilter)

  $PSBoundParameters.Add('Session', $Session) | Out-Null
  $PSBoundParameters.Add('Command', 'listTemplates') | Out-Null
  if ( -not $PSBoundParameters.ContainsKey('Options') ) {
    $PSBoundParameters.Add('Options', $Options) | Out-Null
  }
  $PSBoundParameters.Remove('TemplateFilter') | Out-Null
  
  Invoke-CloudStackApiCommand @PSBoundParameters
<#
.SYNOPSIS
Get CloudStack Templates using the listTemplates CloudStack API Call

.PARAMETER Options
A Hash Table of options to pass to the listTemplates API Call

.PARAMETER Session
An optional session object to control the session used for the API Call

.URL
http://cloudstack.apache.org/docs/api/apidocs-4.2/user/listTemplates.html
#>
}

function Get-ServiceOffering {
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory=$False)] [PSObject]  $Session = $Script:CSSession,
    [Parameter(Mandatory=$False)] [HashTable] $Options
  )
  $PSBoundParameters.Add('Command', 'listServiceOfferings') | Out-Null
  $PSBoundParameters.Add('Session', $Session) | Out-Null
  Invoke-CloudStackApiCommand @PSBoundParameters
<#
.SYNOPSIS
Get CloudStack VMs using the listVirtualMachines CloudStack API Call.

.DESCRIPTION
Get CloudStack VMs using the listVirtualMachines CloudStack API Call.

Refer to the following documentation for specifics of this API Call.
http://cloudstack.apache.org/docs/api/apidocs-4.2/user/listVirtualMachines.html

.PARAMETER Options
A Hash Table of options to pass to the listVirtualMachines API Call.

.PARAMETER Session
An optional session object to control the session used for the API Call.

}

function Get-SnapShot {
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory=$False)] [PSObject]  $Session = $Script:CSSession,
    [Parameter(Mandatory=$False)] [HashTable] $Options
  )
  $PSBoundParameters.Add('Command', 'listSnapshots') | Out-Null
  $PSBoundParameters.Add('Session', $Session) | Out-Null
  Invoke-CloudStackApiCommand @PSBoundParameters
<#
.SYNOPSIS
Get CloudStack Snapshots using the listSnapshots CloudStack API Call.

.DESCRIPTION
Get CloudStack VMs using the listSnapshots CloudStack API Call.

Refer to the following documentation for specifics of this API Call.
http://cloudstack.apache.org/docs/api/apidocs-4.2/user/listSnapshots.html

.PARAMETER Options
A Hash Table of options to pass to the listSnapshots API Call.

.PARAMETER Session
An optional session object to control the session used for the API Call.
#>
}

function Get-NIC {
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory=$True)]  [String]    $VirtualMachineId,
    [Parameter(Mandatory=$False)] [PSObject]  $Session = $Script:CSSession,
    [Parameter(Mandatory=$False)] [HashTable] $Options = @{}
  )
  $PSBoundParameters.Add('Command', 'listNics') | Out-Null
  $PSBoundParameters.Add('Session', $Session) | Out-Null

  $Options.Add('virtualmachineid', $VirtualMachineId)
  if ( -not $PSBoundParameters.ContainsKey('Options') ) {
    $PSBoundParameters.Add('Options', $Options) | Out-Null
  }
  $PSBoundParameters.Remove('VirtualMachineId') | Out-Null

  Invoke-CloudStackApiCommand @PSBoundParameters
<#
.SYNOPSIS
Get CloudStack Nics using the listNics CloudStack API Call.

.DESCRIPTION
Get CloudStack VMs using the listNics CloudStack API Call.

Refer to the following documentation for specifics of this API Call.
http://cloudstack.apache.org/docs/api/apidocs-4.2/user/listNics.html

.PARAMETER Options
A Hash Table of options to pass to the listNics API Call.

.PARAMETER Session
An optional session object to control the session used for the API Call.
#>
}

$CloudStackErrorCode = @{
  '4250' = 'com.cloud.utils.exception.CloudRuntimeException'
  '4255' = 'com.cloud.utils.exception.ExceptionUtil'
  '4260' = 'com.cloud.utils.exception.ExecutionException'
  '4265' = 'com.cloud.utils.exception.HypervisorVersionChangedException'
  '4270' = 'com.cloud.utils.exception.RuntimeCloudException'
  '4275' = 'com.cloud.exception.CloudException'
  '4280' = 'com.cloud.exception.AccountLimitException'
  '4285' = 'com.cloud.exception.AgentUnavailableException'
  '4290' = 'com.cloud.exception.CloudAuthenticationException'
  '4295' = 'com.cloud.exception.CloudExecutionException'
  '4300' = 'com.cloud.exception.ConcurrentOperationException'
  '4305' = 'com.cloud.exception.ConflictingNetworkSettingsException'
  '4310' = 'com.cloud.exception.DiscoveredWithErrorException'
  '4315' = 'com.cloud.exception.HAStateException'
  '4320' = 'com.cloud.exception.InsufficientAddressCapacityException'
  '4325' = 'com.cloud.exception.InsufficientCapacityException'
  '4330' = 'com.cloud.exception.InsufficientNetworkCapacityException'
  '4335' = 'com.cloud.exception.InsufficientServerCapacityException'
  '4340' = 'com.cloud.exception.InsufficientStorageCapacityException'
  '4345' = 'com.cloud.exception.InternalErrorException'
  '4350' = 'com.cloud.exception.InvalidParameterValueException'
  '4355' = 'com.cloud.exception.ManagementServerException'
  '4360' = 'com.cloud.exception.NetworkRuleConflictException'
  '4365' = 'com.cloud.exception.PermissionDeniedException'
  '4370' = 'com.cloud.exception.ResourceAllocationException'
  '4375' = 'com.cloud.exception.ResourceInUseException'
  '4380' = 'com.cloud.exception.ResourceUnavailableException'
  '4385' = 'com.cloud.exception.StorageUnavailableException'
  '4390' = 'com.cloud.exception.UnsupportedServiceException'
  '4395' = 'com.cloud.exception.VirtualMachineMigrationException'
  '4400' = 'com.cloud.exception.AccountLimitException'
  '4405' = 'com.cloud.exception.AgentUnavailableException'
  '4410' = 'com.cloud.exception.CloudAuthenticationException'
  '4415' = 'com.cloud.exception.CloudException'
  '4420' = 'com.cloud.exception.CloudExecutionException'
  '4425' = 'com.cloud.exception.ConcurrentOperationException'
  '4430' = 'com.cloud.exception.ConflictingNetworkSettingsException'
  '4435' = 'com.cloud.exception.ConnectionException'
  '4440' = 'com.cloud.exception.DiscoveredWithErrorException'
  '4445' = 'com.cloud.exception.DiscoveryException'
  '4450' = 'com.cloud.exception.HAStateException'
  '4455' = 'com.cloud.exception.InsufficientAddressCapacityException'
  '4460' = 'com.cloud.exception.InsufficientCapacityException'
  '4465' = 'com.cloud.exception.InsufficientNetworkCapacityException'
  '4470' = 'com.cloud.exception.InsufficientServerCapacityException'
  '4475' = 'com.cloud.exception.InsufficientStorageCapacityException'
  '4480' = 'com.cloud.exception.InsufficientVirtualNetworkCapcityException'
  '4485' = 'com.cloud.exception.InternalErrorException'
  '4490' = 'com.cloud.exception.InvalidParameterValueException'
  '4495' = 'com.cloud.exception.ManagementServerException'
  '4500' = 'com.cloud.exception.NetworkRuleConflictException'
  '4505' = 'com.cloud.exception.PermissionDeniedException'
  '4510' = 'com.cloud.exception.ResourceAllocationException'
  '4515' = 'com.cloud.exception.ResourceInUseException'
  '4520' = 'com.cloud.exception.ResourceUnavailableException'
  '4525' = 'com.cloud.exception.StorageUnavailableException'
  '4530' = 'com.cloud.exception.UnsupportedServiceException'
  '4535' = 'com.cloud.exception.VirtualMachineMigrationException'
  '4540' = 'com.cloud.async.AsyncCommandQueued'
  '4545' = 'com.cloud.exception.RequestLimitException'
  '9999' = 'com.cloud.api.ServerApiException'
}

function Get-CloudStackErrorCode {
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory=$True)] [Alias('Code','Error','Id')] [Int32] $ErrorCode    
  )
  
  if ( $CloudStackErrorCode.keys -contains $ErrorCode ) {
    return $CloudStackErrorCode.($ErrorCode)
  }
  else {
    Throw "Could not find exception for error code ($ErrorCode) in list of CloudStack exceptions"
  }
<#
.SYNOPSIS
Return the underlying CloudStack Exception given a CloudStack error code.

.DESCRIPTION
Return the underlying CloudStack Exception given a CloudStack error code.

This is done using an internal lookup using information derived from 
the CloudStack 4.2 code base and may not be fully up-to-date.

.PARAMETER ErrorCode
The CloudStack ErrorCode as an integer.
#>
}

function Sync-Api {
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory=$False)] $Session = $Script:CSSession    
  )

  $ApiSchema = $Script:ApiSchema `
    = Invoke-CloudStackApiCommand -Command 'listApis' -Session $Script:CSSession

  return $ApiSchema
}

function Get-Api {
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory=$False)] [String]    $Command,
    [Parameter(Mandatory=$False)] [String]    $CommandGroup,
    [Parameter(Mandatory=$False)] [String]    $Description,
    [Parameter(Mandatory=$False)] [Switch]    $Params,
    [Parameter(Mandatory=$False)] [Switch]    $Response,
    [Parameter(Mandatory=$False)] [HashTable] $Options,
    [Parameter(Mandatory=$False)] [PSObject]  $Session = $Script:CSSession
  )

  # Update API Schema Cache
  if ( -not($Script:ApiSchema) ) { $ApiSchema = Sync-Api }

  # Tack on the 'group' (CommandGroup) property
  # And sort objects based on their group
  $ApiSchema = $ApiSchema | %{
    $Group = $Null
    if ( $_.name -cmatch '^([a-z]+)(.*)$' ) {
      $Group = $Matches[2] | %{ # Normalize to singulars
        $_ = $_ -replace 'ies$','y'
        $_ = $_ -replace 's$'
        $_
      } 
    }
    $CommandGroupName = if ( $Group ) { $Group } else { 'Unknown' }
    $_ | Add-Member NoteProperty 'group' $CommandGroupName -Force 
    @{ 'g' = $Group; 'v' = $_; }
  } | sort { $_.g } | %{ $_.v } # Schwartzian transform

  if ( $Command ) {
    $Result = $ApiSchema | ?{ $_.name -imatch $Command }
  }
  elseif ( $CommandGroup ) {
    $Result = $ApiSchema | ?{ $_.group -imatch $CommandGroup }
  }
  elseif ( $Description ) {
    $Result = $ApiSchema | ?{ $_.name -imatch $Description }
  }
  else {
    $Result = $ApiSchema
  }

  if ( $Params ) {
    $Result = $Result | %{ $_.params }
  }
  elseif ( $Response ) {
    $Result = $Result | %{ $_.response }
  }
  
  return $Result

<#
.SYNOPSIS
Get CloudStack APIs using the listApis CloudStack API Call.

.DESCRIPTION
Lists all available apis on the server, provided by the Api Discovery plugin

This function is only supported on CloudStack 4.x or later where 
API Discovery is supported.

Refer to the examples for usage.

Refer to the following documentation for specifics of this API Call.
http://cloudstack.apache.org/docs/api/apidocs-4.2/user/listApis.html

.PARAMETER Command
Regular expression to filter API objects on their 'name' property.

.PARAMETER CommandGroup
Regular Expression to filter API objects on their 'group' property.

The CommandGroup is not a CloudStack property and 
is a property added by to this function.

.PARAMETER Description
Regular expression to filter API object on their 'description' property.

.PARAMETER Expose
The type of proprties to expose in the output - is one of 'params' or 'reponse'.

.PARAMETER Options
A Hash Table of options to pass to the listApis API Call.

.PARAMETER Session
An optional session object to control the session used for the API Call.

.EXAMPLE

PS> Get-Api -Command 'listPhysicalNetwork' 

group       : PhysicalNetwork
name        : listPhysicalNetworks
description : Lists physical networks
since       : 3.0.0
isasync     : false
related     :
params      : {zoneid, name, id, keyword...}
response    : {vlan, id, state, zoneid...}

.EXAMPLE

PS> Get-Api -Command 'listPhysicalNetwork' -Expose params

name        : zoneid
description : the Zone ID for the physical network
type        : uuid
length      : 255
required    : false
related     :

name        : name
description : search by name
type        : string
length      : 255
required    : false

...

.EXAMPLE 
PS> Get-Api -Command 'listPhysicalNetwork' -Expose response

name                                                description                                        type
----                                                -----------                                        ----
vlan                                                the vlan of the physical network                   string
id                                                  the uuid of the physical network                   string
state                                               state of the physical network                      string
zoneid                                              zone id of the physical network                    string
name                                                name of the physical network                       string
broadcastdomainrange                                Broadcast domain range of the physical network     string
tags                                                comma separated tag                                string
domainid                                            the domain id of the physical network owner        string
networkspeed                                        the speed of the physical network                  string
isolationmethods                                    isolation methods                                  string

#>
}

function Get-ApiDocumentation {
  [CmdletBinding()]
  Param(
    [String] $Command    
  )
}
