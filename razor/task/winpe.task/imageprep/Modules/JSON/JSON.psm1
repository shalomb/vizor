# PowerShell module

# JSON functions for Powershell v2

# Based on
#   'ConvertTo-JSON for Powershell 2.0' https://gist.github.com/mdnmdn/6936714

function ConvertTo-EscapedJSONString {
  [CmdletBinding()] Param (
    [Parameter(
      Position=0, 
      Mandatory=$true, 
      ValueFromPipeline=$true,
      ValueFromPipelineByPropertyName=$true)
    ] [AllowEmptyString()] [String] $String = $Null
  )

  # Should conform to escaping as per RFC 4627
  if ( $String -eq $Null ) {
    'null'
  }
  else {
    $String.Replace('"','\"').Replace('\','\\').Replace("`n",'\n').Replace("`r",'\r').Replace("`t",'\t')
  }
}

function ConvertTo-JSON {
  [CmdletBinding()] Param(
    [Parameter(
      Position=0, 
      Mandatory=$true, 
      ValueFromPipeline=$true,
      ValueFromPipelineByPropertyName=$true)
    ] [AllowNull()] [AllowEmptyString()] [Object[]] $InputObject = @(),
    [Int]     $MaxDepth = 4,
    [Switch]  $ForceArray = $false
  )

  Begin {
    $Data = @()
  }

  Process { 
    $Data += @($InputObject)
  }

  End {

    if ($Data.length -eq 1 -and $forceArray -eq $false) {
      $Value = $Data[0]
    } else {
      $Value = $Data
    }

    if ($Value -eq $null) {
      return "null"
    }


    switch -regex ( $Value.GetType().Name ) {
      'String|Char'           { return  "`"{0}`"" -f (ConvertTo-EscapedJSONString $Value) }

      'Int\d+|Double'         { return  "$Value" }

      '(System\.)?Object\[\]' { # array
        if ($MaxDepth -le 0){ return "`"$Value`"" }

        $JSON = ''
        foreach($elem in $Value){
          #if ($elem -eq $null) {continue}
          if ($JSON.Length -gt 0) { $JSON +=', ' }
          $JSON += ($elem | ConvertTo-JSON -MaxDepth ($MaxDepth -1))
        }
        return "[" + $JSON + "]"
      }

      '(System\.)?Hashtable'  { # Hashtable
        $JSON = ''
        foreach($Key in $Value.Keys){
          if ($JSON.Length -gt 0) { $JSON +=', ' }
          $JSON += "`"{0}`":{1}" -f $Key , ($Value[$Key] | ConvertTo-JSON -MaxDepth ($MaxDepth -1))
        }
        return ("{" + $JSON + "}")
      }

      'Boolean'             { return  $Value.ToString().ToLower() }

      '(System\.)?DateTime' { return  "`"{0:yyyy-MM-dd}T{0:HH:mm:ss}`"" -f $Value }

      default { # Object
        if ($MaxDepth -le 0) { return  "`"{0}`"" -f (ConvertTo-EscapedJSONString $Value) }

        return "{" +
          (($Value | Get-Member -MemberType *property | % {
            if ( $v = $Value.($_.Name) | ConvertTo-JSON -MaxDepth ($MaxDepth -1) ) {
              "`"{0}`": {1}" -f $_.Name, $v
            }
            else {
              "`"{0}`": {1}" -f $_.Name, $Null
            }
          }) -join ', ') + 
        "}"
      }
    }

  }
}

function ConvertFrom-JSON {
  [CmdletBinding()] Param(
    [Parameter(ValueFromPipeline=$True,  Position=0)] 
      [Object]  $InputObject
  )

  Begin {
    Add-Type -AssemblyName System.Web.Extensions
  }

  Process {
    try {
      $Dictionary = (New-Object -TypeName System.Web.Script.Serialization.JavascriptSerializer).DeSerializeObject($InputObject)
      $PSObject   =  New-Object -TypeName PSObject -Property ([HashTable]$Dictionary)
    } catch [Exception] {
      throw $Error[0]
    }
    $PSObject
  }
}

function Submit-ToUri {
  [CmdletBinding()] Param (
    [String] $Uri,
    [String] $Body
  )

  $Request = [System.Net.WebRequest]::Create($Uri) 
  $Request.Method = 'POST'
  $Request.ContentType = 'application/json'

  $PostStr = [System.Text.Encoding]::UTF8.GetBytes($Body)
  $Request.ContentLength = $PostStr.Length

  # Write request
  $RequestStream = $Request.GetRequestStream()
  $RequestStream.Write($PostStr, 0,$PostStr.length)
  $RequestStream.Close()

  # Read response
  $Reader = New-Object System.IO.Streamreader -ArgumentList $Request.GetResponse().GetResponseStream()  
  $Response = $Reader.ReadToEnd()                                                                   
  $Reader.Close()                                                                                 

  return $Response 
}

function Get-FromUri {
  [CmdletBinding()] Param (
    [String]    $Uri
  )

  $Request = [System.Net.WebRequest]::Create($Uri) 
  $Request.Method = 'GET'
  $Request.ContentType = 'application/json'

  # read response
  $Reader = New-Object System.IO.Streamreader -ArgumentList $Request.GetResponse().GetResponseStream()  
  $Response = $Reader.ReadToEnd()                                                                   

  try { 
    $Reader.Close()                                                                                 
  } catch {}                                                                                        

  return $Response 
}

# Test Cases
# "a" | ConvertTo-JSON
# dir \ | ConvertTo-JSON
# (get-date) | ConvertTo-JSON
# (dir \)[0] | ConvertTo-JSON -MaxDepth 1
# @{ "asd" = "sdfads" ; "a" = 2 } | ConvertTo-JSON
