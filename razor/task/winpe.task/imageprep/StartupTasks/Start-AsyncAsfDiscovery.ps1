<#
.SYNOPSIS
   Script discovers any WCF discoverable service
   to be run.
   
   Copyright (c) 2011 UK Test Automation, Citrix Systems UK Ltd.
   
.DESCRIPTION
   Uses UDP multicast to discover any WCF discoverable service
   $ScriptCallbackStr should take a uri string as a parameter
#>
param(
	[int]$MaxResults = 1, 
	[int]$ProbeTTL = 10,
	[string] $ServiceContract = "ISimpleDiscoverableRestService",
	[ValidateScript({if($_ -ne [string]::Empty){Test-Path $_}})] 
	[string] 
	$CertFilePath = $null,
	[switch] $AutoRetryOff,
	[switch] $AsyncOff,
	[switch]$LocalHost,
	[switch] $Debug,	
	[string]$ScriptCallbackStr# script 
) 

# Load to enable use of XElement
[void][Reflection.Assembly]::LoadWithPartialName("System.Xml.Linq")
[Void][Reflection.Assembly]::LoadWithPartialName("System.Security")

$VerbosePreference = "continue"

# if netwrok hasn't started yet wait for this time before retrying
$NoNetworkWaitInSecs = 10

if($ScriptCallbackStr -eq [string]::Empty)
{
	$ScriptCallback = {
		
		[CmdletBinding()]
	    param(
	        [parameter(
	            mandatory=$true,position=0)][PSObject]$taskData
		)
		Write-Host "Default callback scriptblock $taskData"
		
		# web download file
		function DownLoadFile($fileUri, $destPath)
		{
			$filename = $fileUri.Segments[$fileUri.Segments.Length - 1]
			
			$webClient = new-object System.Net.WebClient
			$webClient.Headers.Add("user-agent", "PowerShell Script")
			$destFilePath = join-path $destPath $filename
			
			Write-Verbose "Downloading $fileUri to $destFilePath"
			
			try
			{
        # Workaround for BUG0421743
        # Clear the DNS cache to allow for the call to DownloadFile() to use the most 
        # most current FQDN of the webserver hosting $scriptFileUri without requiring
        # a restart of this script.
        & ipconfig.exe /flushdns | Out-Null

				$webClient.DownloadFile($fileUri, $destFilePath)
				return $destFilePath
			}
			catch 
			[System.Net.WebException]
			{
				#TODO handle re-direct response
				Write-Verbose "WebException $_"
				throw
			}
		}
		
		#create a random dir for the download
		$rand = [IO.Path]::GetRandomFileName()	
		$destPath = join-path $env:temp $rand	
		mkdir $destPath | Out-Null
		
		$xml = $taskData.TasksXml
		
		# parse the taskxml 
		$xelement = [System.Xml.Linq.XElement]::Parse($taskData.TasksXml)
		
		$taskElements = $xelement.Elements() 
		
		# set glabal variable for service uri
		# this allows the downloaded script(s) to access the service correctly is needed
		Set-Variable -Scope Global -Name ServiceUri -Value $taskData.ServiceUri
				
		try
		{
			foreach($task in $taskElements)
			{
				$scriptFileUri = [Uri]$task.Element("scriptpath").Value
				$dataFileUri = [Uri]$task.Element("datapath").Value
				
				if(-not $scriptFileUri.IsAbsoluteUri)
				{
					Write-Debug "Task file must be full path found: $fileUri"
					
					$scriptFileUri = New-Object Uri -ArgumentList $taskData.ServiceUri, $scriptFileUri
				}
				
				if(-not $dataFileUri.IsAbsoluteUri)
				{
					Write-Debug "Task file must be full path found: $fileUri"
					
					$dataFileUri = New-Object Uri -ArgumentList $taskData.ServiceUri, $dataFileUri
				}
				  
				$localTaskScriptPath = DownLoadFile $scriptFileUri $destPath				
				$localTaskDataPath = DownLoadFile $dataFileUri $destPath	
				
				# set a global variable rather than pass args to the script to avoid any path escaping issues with iex
				Set-Variable -Scope Global -Name DataFilePath -Value $localTaskDataPath
				
				# invoke the script
				iex -Command "&'$localTaskScriptPath'" 
			}
			
			# only remove temp path when the script doesn't fail
			rm $destPath -Force -Recurse
		}
		catch
		{
			Write-Host "Error running $localTaskScriptPath $localTaskDataPath Error: $_"
			throw
		}
	}
}
else
{
	# convert the scriptblock string to a scriptblock
	$ScriptCallback = $executioncontext.invokecommand.NewScriptBlock($ScriptCallbackStr)
}

function Get-ScriptDirectory
{
	$Invocation = (Get-Variable MyInvocation -Scope 1).Value
	Split-Path $Invocation.MyCommand.Path
}

$scriptDir = Get-ScriptDirectory

# import log4net module
# Import-Module $scriptDir\PSlog4Net 

$success = $false

Write-Host "Main: Starting Service Discovery"

$udpport = 3702 # standard ws-discovery udp port

# clean up jobs
Function CleanJobs
{
	# clean up jobs
	Write-Verbose "CleanJobs: clean up all running jobs"
	Get-Job | Stop-Job
	Get-Job | Remove-Job
}

Function MacXml
{
	$evidenceXmlFmt = "<evidence>{0}</evidence>"
	$evidenceItemXmlFmt = "<item>{0}</item>"
	
	$nics =[System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()
	
	if($nics.Length -eq 0)
	{
		Write-Warning "No NICs found"
		return $null
	}
	# if (nic.NetworkInterfaceType == NetworkInterfaceType.Ethernet || nic.NetworkInterfaceType == NetworkInterfaceType.Wireless80211)
                    
	$itemXmlStr = [string]::Empty
	
	foreach($nic in $nics)
	{
		if($nic.OperationalStatus -eq [System.Net.NetworkInformation.OperationalStatus]::Up)
		{
			if(($nic.NetworkInterfaceType -eq [System.Net.NetworkInformation.NetworkInterfaceType]::Ethernet) `
				-or ($nic.NetworkInterfaceType -eq [System.Net.NetworkInformation.NetworkInterfaceType]::Wireless80211))
			{
				$itemXmlStr += $evidenceItemXmlFmt -f $nic.GetPhysicalAddress()
			}
		}
	}
	
	if($itemXmlStr -eq [string]::Empty)
	{
		Write-Warning "No Ethernet or Wireless80211 interfaces found"
		return $null
	}
	
	$evidenceXmlStr = $evidenceXmlFmt -f $itemXmlStr
	
	Write-Verbose "Mac address xml $evidenceXmlStr"
	
	return $evidenceXmlStr
}



# Probe "fe80::5efe:10.70.33.24%15" "et" "w" 10 3702

# scriptblock to pass to the async execution of the udp probe
$functions = {

	[void][Reflection.Assembly]::LoadWithPartialName("System.Xml.Linq")
	$VerbosePreference = "continue"
	
	# control the number of devices the multicast will pass through
	# set to 2 for a 2 router secenario for ASf split hypervisor
	$ttl = 2

	Function Probe($ipaddressStr, $probeMessage, $messageid, $ProbeTTL, $udpport)
	{
		Write-Host "Probe: Service Discovery: Interface=$ipaddressStr"
		
		# get bytes for soap probe message
		$sendBuffer = [System.Text.Encoding]::ASCII.GetBytes($probeMessage)

		# store probematch reply and any replying server 
		$probeMatchMessage = "<>"
		$discoveredServer = "server not found"

		$ipaddress = [Net.IPAddress]::Parse($ipaddressStr)

	    # set multicast address for correct AddressFamily IPv4 vs IPv6
		$remoteEndPoint = New-Object Net.IPEndPoint([Net.IPAddress]::IPv6Any,0)
		$wsdMulticastAddr = [System.Net.IPAddress]::Parse("FF02::C")		

	    if($ipaddress.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetworkV6)
		{
			$remoteEndPoint = New-Object Net.IPEndPoint([Net.IPAddress]::Any,0)
			$wsdMulticastAddr = [System.Net.IPAddress]::Parse("239.255.255.250")	
		}
		
		# listener for unicast reply
		$ipEndpoint = New-Object Net.IPEndPoint($ipaddress,0)
	    $udpclient = New-Object Net.Sockets.UdpClient($ipEndpoint)
			
		$wsdMulticastEndPoint = New-Object System.Net.IPEndPoint($wsdMulticastAddr, $udpport);
		$udpclient.JoinMulticastGroup($wsdMulticastAddr, $ttl)
		
		Write-Verbose "Probe: wsdMulticastEndPoint = $wsdMulticastEndPoint"

		# begin listening for unicast reply
		$ar = $udpclient.BeginReceive($null,$null)	

		try
		{
	 	# send out a the probe x3
			$udpclient.Send($sendBuffer, $sendBuffer.Length, $wsdMulticastEndPoint) | Out-Null
			$udpclient.Send($sendBuffer, $sendBuffer.Length, $wsdMulticastEndPoint) | Out-Null
			$udpclient.Send($sendBuffer, $sendBuffer.Length, $wsdMulticastEndPoint) | Out-Null
		}
		catch
		{
			throw "Probe: Failed whilst sending multicast probe for Interface: $ipaddressStr"
		}
		
		# true if triggered by reply
		Write-Host "Probe: Waiting for ProbeMatch reply: $ProbeTTL sec timeout: Interface=$ipaddressStr"
		
		if($ar.AsyncWaitHandle.WaitOne($ProbeTTL * 1000) -ne $true)
		{
			# ipv6 has failed try ipv4 multicast
			Write-Host "Probe: Discovery wait timed out: Interface=$ipaddressStr"
			
			# clean up
			$udpclient.Close()
			$ar.AsyncWaitHandle.Close()
		}
		else
		{
			# reply received
			$recbuffer = $udpclient.EndReceive($ar, [REF] $remoteEndPoint) 
			$probeMatchMessage = [System.Text.Encoding]::ASCII.GetString($recbuffer, 0, $recbuffer.Length)
			
	        Write-Verbose "Probe: $remoteEndPoint"
	        
			Write-Host "Probe: ProbeMatch received from > $remoteEndPoint < Interface=$ipaddressStr"
			
			Write-Verbose "Probe: $probeMatchMessage"		
			
			# clean up
			$udpclient.Close()
			$ar.AsyncWaitHandle.Close()		
			
			# ProbeMatch example
			#<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:a="http://www.w3.org/2005/08/addressing">
			#<s:Header><a:Action s:mustUnderstand="1">http://docs.oasis-open.org/ws-dd/ns/discovery/2009/01/ProbeMatches</a:Action>
			#<h:AppSequence InstanceId="1327944395" MessageNumber="1" xmlns:h="http://docs.oasis-open.org/ws-dd/ns/discovery/2009/01"/>
			#<a:RelatesTo>urn:uuid:e092ee8d-b73b-4fa9-ab54-023199ccf791</a:RelatesTo><a:MessageID>urn:uuid:e05d15f2-6528-483b-81f1-42c1725c5265</a:MessageID>
			#<ActivityId CorrelationId="afe55045-4bb2-4a1b-80b8-8caae3ae7092" xmlns="http://schemas.microsoft.com/2004/09/ServiceModel/Diagnostics">c00188b1-7c19-4937-a7ca-f160b4e21f9e</ActivityId>
			#</s:Header><s:Body><ProbeMatches xmlns="http://docs.oasis-open.org/ws-dd/ns/discovery/2009/01" xmlns:i="http://www.w3.org/2001/XMLSchema-instance"><ProbeMatch><a:EndpointReference>
			#<a:Address>http://10.70.33.20/AsfBootStrapSvc/service.svc</a:Address>
			#</a:EndpointReference><d:Types xmlns:d="http://docs.oasis-open.org/ws-dd/ns/discovery/2009/01" xmlns:dp0="http://tempuri.org/">dp0:IBootStrapTaskRunner</d:Types>
			#<XAddrs>http://10.70.33.20/AsfBootStrapSvc/service.svc</XAddrs><MetadataVersion>0</MetadataVersion></ProbeMatch></ProbeMatches></s:Body></s:Envelope>

			# parse the soap reply  
			$xelement = [System.Xml.Linq.XElement]::Parse($probeMatchMessage)

			$reader = $xelement.CreateReader()

			Write-Verbose "Probe: Looking for xml element <a:RelatesTo>"
			$reader.ReadToFollowing("a:RelatesTo") | Out-Null
		
			$relatesToMsgId =  $reader.ReadString()

			# reply is for the wrong probe
			if($messageid -ne $relatesToMsgId)
			{
				throw "Probe: ProbeMatch MessageId didn't match: Expected: $relatesToMsgId => Received: $messageid"
			}

			Write-Verbose "Probe: Looking for xml element <a:Address>"
			# move to the address field
			$reader.ReadToFollowing("a:Address") | Out-Null

			# get the service URI
			$serviceUriStr = $reader.ReadString()			
	        
	        $inUri = [Uri]$serviceUriStr
			
			$ipHostEntry = [System.Net.Dns]::GetHostEntry($remoteEndPoint.Address);
            $name = $ipHostEntry.HostName;
			
			Write-Verbose "Probe: resolved $($remoteEndPoint.Address) to $name)"
			
			if([string]::IsNullOrEmpty( $name))
			{			
		        if($remoteEndPoint.Address.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetworkV6)
		        {        
		            $v6IP = "[$($remoteEndPoint.Address)]"
		            Write-Verbose "Probe: $v6IP" 
		            $serviceUri = [Uri]$serviceUriStr.Replace($inUri.Host, $v6IP) 									
		        }
		        else
		        {
		            $serviceUri = [Uri]$serviceUriStr.Replace($inUri.Host, $remoteEndPoint.Address)   
				}			
			}
			else
			{
				$serviceUri = [Uri]$serviceUriStr.Replace($inUri.Host, $name)  
			}
			
			Write-Verbose "Probe: serviceUri $serviceUriStr => $serviceUri"
			
			# this means that this SUT is not trusted by the ws-discovery server			
			if($serviceUri.ToString() -like "*/untrusted")
			{
				Write-Warning "Discovery request rejected by $serviceUriStrIP"
				return
			}			
			
			# get the xml that contains the list of tasks to run after discovery
			Write-Verbose "Probe: Looking for xml element <postdiscoverytasks>"
			$reader.ReadToFollowing("postdiscoverytasks") | Out-Null
			
			$tasksXml = $reader.ReadOuterXml()			
		
			Write-Verbose "Probe: Found post discovery tasks xml : $tasksXml"
			
			$Object = New-Object PSObject                                       
            $Object | add-member Noteproperty ServiceUri $serviceUri 
            $Object | add-member Noteproperty TasksXml $tasksXml 
			
			return $Object
			
#			# if tasks list isn't included just return the service uri
#			if($tasksXml -eq [string]::Empty)
#			{
#		        Write-Verbose "Probe: Replace Name with IP adrress"
#				Write-Verbose "Probe: $serviceUriStr > $serviceUriStrIP"
#				Write-Verbose "Probe: Found URI: $serviceUriStrIP"
#		        
#				return $serviceUriStrIP
#			}
#			else
#			{
#			}
		}
	}
}


# Get the service uri from the job and retrieve the boostrap task from the service
Function RunCallback($job)
{
	$taskData = Receive-Job $job
	
	if($taskData -eq $null)
	{
		Write-Verbose "Removing Job: Id=$($job.Id) State=$($job.State)"
		Remove-Job $job
	}
	else
	{
		Write-Verbose "Processing Job: Id=$($job.Id) State=$($job.State)"		

		Write-Verbose "Task data: @ $taskData"
        
		# pass the service URI to the callback script
		if($ScriptCallback -ne $null)
		{
			$ScriptCallback.Invoke( $taskData )
			Write-Verbose "Script callback complete"
		}
		else
		{
			Write-Verbose "No call back script passed"
		}		
		
		Write-Verbose "Removing Job: Id=$($job.Id) State=$($job.State)"
		Remove-Job $job
		
		return $true
	}
}

# Start each discovery probe request in a background job
Function StartProbeJob($ipaddressStr)
{
	# Create soap probe message id
	$messageid = [Guid]::NewGuid().ToString()
	$messageid = "urn:uuid:$messageid" 	

	$probeMessageformat = '<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:a="http://www.w3.org/2005/08/addressing">' + 
					'<s:Header><a:Action s:mustUnderstand="1">http://docs.oasis-open.org/ws-dd/ns/discovery/2009/01/Probe</a:Action><a:MessageID>{0}</a:MessageID>' + 
					'<a:ReplyTo><a:Address>http://www.w3.org/2005/08/addressing/anonymous</a:Address></a:ReplyTo>' +
					'<a:To s:mustUnderstand="1">urn:docs-oasis-open-org:ws-dd:ns:discovery:2009:01</a:To>' + 
					'</s:Header><s:Body><Probe xmlns="http://docs.oasis-open.org/ws-dd/ns/discovery/2009/01">' +
					'<d:Types xmlns:d="http://docs.oasis-open.org/ws-dd/ns/discovery/2009/01" xmlns:dp0="http://tempuri.org/">dp0:{1}</d:Types>' +
					'<MaxResults xmlns="http://schemas.microsoft.com/ws/2008/06/discovery">{2}</MaxResults>' +
					'<Duration xmlns="http://schemas.microsoft.com/ws/2008/06/discovery">PT{3}S</Duration>{4}</Probe></s:Body></s:Envelope>'

	$probeMessage = [string]::Format($probeMessageformat, $messageid, $ServiceContract, $MaxResults, $ProbeTTL, $probeextensionxml)
	
	Write-Debug $probeMessage
	
	# create script to call the Probe function
	# $script = [scriptblock]::Create("Probe '$ipaddressStr' '$probeMessage' $messageid $ProbeTTL $udpport")
	$script = $executioncontext.invokecommand.NewScriptBlock("Probe '$ipaddressStr' '$probeMessage' $messageid $ProbeTTL $udpport")
		
	## Use for ddebugging the code in the $functions scriptblock
	#Invoke-Command -ScriptBlock $script

	# start a background job to send the discovery multicast probe request
	$ret = Start-Job -InitializationScript $functions -ScriptBlock $script -Name $ipaddressStr
	Write-verbose "Start job for $($ret.Name)"
	
	# if running synchronously wait on the job here
	if($AsyncOff)
	{
		Write-Host "Starting Synchronous discovery probe: Interface=$ipaddressStr"
		
		$ret | Wait-Job | Out-Null
		
		try
		{		
            Write-Host "1 $($success)"
			if(RunCallback($ret) -eq $true)
			{
				Set-Variable -Name "success" -Value $true -Scope 1
            	Write-Host "2 $($success)"
			}
		}
		catch
		{
            Write-Warning "Error running job $($ret.Name)"
		}
        finally
        {
            Write-Verbose "Asyncoff StartProbeJob complete result = $success"
        }
	}
	else
	{
		Write-Host "Starting Asynchronous discovery probe: Interface=$ipaddressStr"
	}
}



# clean up all running jobs
CleanJobs

while($true)
{
	# add an xml blb containg the mac addresses for ethernet and wirless nics
	# used to validate this is a known system to the controller
	$probeextensionxml = MacXml
	
	if($probeextensionxml -eq $null)
	{
		Write-Warning "Network not present. Wait $NoNetworkWaitInSecs secs and try again"
		sleep $NoNetworkWaitInSecs 
		continue
	}

	# try order IPv6 => IPv4 => IPv6 loopback => IPv4 loopback
	
	# get all the interfaces for this machine from inslide loop in case DHCP has is slow
	# exclude IPv4 LinkLayerAddress address 169.254.x.x as Udpclient fails

	$nics = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()| Where-Object{$_.OperationalStatus -eq "Up" -and $_.NetworkInterfaceType -ne "Tunnel"}
	$unicast = $nics | foreach{$_.GetIPProperties()} | foreach{$_.UnicastAddresses} 
	$ipAddresses = $unicast | where {($_.SuffixOrigin -ne "LinkLayerAddress" -or $_.Address.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetworkV6)`
			-and -not([Net.IPAddress]::IsLoopback($_.Address))} | foreach {$_.Address}
 	
	try
	{
		Write-Verbose "Main: Try IPv6 interfaces"
		$ipAddresses | Where-Object {$_.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetworkV6} | Foreach-Object { StartProbeJob($_) }
		if($success -and $AsyncOff)
		{
		    Write-Verbose "Main: Synchronous probe and job finished"
		    break;
		}
    }
	catch
	{
		Write-Warning "Main: Probe on IPv6 interfaces failed"
	}
	
	try
	{
		Write-Verbose "Main: Try IPv4 interfaces"
		$ipAddresses | Where-Object {$_.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork} | Foreach-Object { StartProbeJob($_) }
		if($success -and $AsyncOff)
		{
			Write-Verbose "Main: Synchronous probe and job finished"
			break;
		}
    }
	catch
	{
		Write-Warning "Probe on IPv4 interfaces failed $_"
	}
	
	if($LocalHost)
	{	
		try
		{
			Write-Verbose "Main: Try IPv6 loopback interface"
			StartProbeJob([Net.IPAddress]::IPv6Loopback)
			if($success -and $AsyncOff)
			{
			    Write-Verbose "Main: Synchronous probe and job finished"
			    break;
			}
		}
		catch
		{
			Write-Warning "Main: Probe on IPv6 loopback failed $_"
		}
			
		try
		{
			Write-Verbose "Main: Try IPv4 loopback interface"
			StartProbeJob([Net.IPAddress]::Loopback)
			if($success -and $AsyncOff)
			{
			    Write-Verbose "Main: Synchronous probe and job finished"
			    break;
			}
		}
		catch
		{
			Write-Warning "Main: Probe on IPv4 loopback failed. $_"
		}	
	}
	
	if(-not($AsyncOff))
	{
		# loop while jobs list still has running items
		while($true)
		{			
			sleep 5
			$jobs = Get-Job
			
			# if a job isn't running retrieve the probe result and process the returned URI
			# if the probe has failed or has been rejected remove the job
			$jobs | Where-Object{$_.State -ne 'Running'} | ForEach-Object {$job = $_; try{if(RunCallback($job)){Write-Verbose "Tasks complete"; $success=$true; break}}catch{Write-Error $_.Exception ; Remove-Job $job}}
			
			# check the job list and break if it is empty
			$jobs = Get-Job

			$jobs 
	
			if($jobs -eq $null -or $jobs.Length -eq 0)
			{
				break
			}
		}
	}

	if($AutoRetryOff -or $success)
	{
		# clean up all running jobs, need to do this or powershell.exe will crash
		CleanJobs	
		break
	}
}

if($success)
{
	Write-Host "Main: Discovery Complete and callback"
}
else
{
	throw "Service discovery and callback execution process failed: No services found."
}






