# PowerShell v2.0

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'STOP'

function Get-DomainName {
  [CmdletBinding()] Param()
      if ( $Env:USERDNSDOMAIN ) { $Env:USERDNSDOMAIN }
  elseif ( $Env:USERDOMAIN    ) { $Env:USERDOMAIN    } 
  elseif ( $Env:COMPUTERNAME  ) { $Env:COMPUTERNAME  }
    else { Throw "Unable to determine current domain name." }
}

function Get-PSNetworkCredential {
  [CmdletBinding()] Param(
    [ Parameter( Mandatory=$True, ValueFromPipeline=$True,
      ValueFromPipelineByPropertyName=$True ) ]
      [System.Management.Automation.PSCredential] $PSCredential
  )
  $PSCredential | %{ $_.GetNetworkCredential() }
}

function New-PSCredential {
  [CmdletBinding()] Param(
    [String] $Username,
    [String] $Password
  )

  if ( -not($Username) ) {
    $DomainName = Get-DomainName
    $DefaultUserName = "{0}@{1}" -f $Env:USERNAME, $DomainName
    Write-Host "Username [$DefaultUserName] : " -NoNewLine
    $Username = if ( $Username = Read-Host ) { $Username } else {  $DefaultUserName }
  }

  $SecureString = if ( -not($Password) ){
                    Write-Host "Password : " -NoNewLine
                    Read-Host -AsSecureString 
                  }
                  else {
                    ConvertTo-SecureString -String $Password -AsPlainText -Force
                  }

  Write-Host -Fore cyan "UserName : $UserName"
  New-Object -TypeName System.Management.Automation.PSCredential -Argumentlist $Username,$SecureString
}

function Restore-PSCredential {
  [CmdletBinding()] Param(
    [String] $Username = '.',
    [String] $PSCredentialVault = (Join-Path $Env:PROGRAMDATA 'PSCredentials')
  )

  if ( Test-Path $PSCredentialVault ) {
    $Files = ls $PSCredentialVault -Recurse | ?{ -not($_.PSIsContainer) } | %{ $_.FullName }
    foreach ( $File in $Files ) {
      try {
        $PSCredentialObject = Import-CliXml -Path $File
        
        ($ResolvedUsername, $ResolvedDomainName) = ($PSCredentialObject.Username, $PSCredentialObject.Domain)
        
        if ( -not($ResolvedDomainName) ) {
          if ( $ResolvedUsername -imatch '.*@.*' ) { 
            ($ResolvedUserName, $ResolvedDomainName) = ($ResolvedUsername -split '@')
          }
        }
        
        if ( $ResolvedDomainName ) {
          $FullUsername = '{0}@{1}' -f $ResolvedUsername, $ResolvedDomainName
        }

        if ( ($PSCredentialObject.Username -imatch $Username) -or ($FullUsername -imatch $Username) ) {
          Write-Host -Fore Cyan "$FullUsername $ResolvedUsername matches $($PSCredentialObject.Username -imatch $Username)"
          $SecurePassword = $PSCredentialObject.SecureString | ConvertTo-SecureString
          $PSCredential = New-Object -TypeName System.Management.Automation.PSCredential -Argumentlist $FullUsername,$SecurePassword
          Write-Output $PSCredential
        }

      } catch {
        Write-Warning "Exception reading PSCredential from '$File' : $_"
      }
    }
  }
  else {
    Write-Error "PSCredentials directory '$PSCredentialVault' does not exist."
  }
}

function Save-PSCredential {
  [CmdletBinding()] Param(
    [ Parameter( Mandatory=$True, ValueFromPipeline=$True,
      ValueFromPipelineByPropertyName=$True ) ]
      [System.Management.Automation.PSCredential] $PSCredential,
    [String] $PSCredentialVault = (Join-Path $Env:PROGRAMDATA 'PSCredentials'),
    [Switch] $Force
  )

  $NetCredential = Get-PSNetworkCredential -PSCredential $PSCredential

  $UserName = $NetCredential.Username
  $Domain   = $NetCredential.Domain

  if ( -not($Domain) ) {
    if ( $NetCredential.Username -imatch '.*@.*' ) { 
      ($UserName, $Domain) = ($NetCredential.Username -split '@')
    }
    else {
      $Domain = Get-DomainName
    }
  }

  Write-Host -Fore Green ("Username : {0}" -f $UserName)
  Write-Host -Fore Green ("  Domain : {0}" -f $Domain)

  [System.IO.FileInfo] $CredentialsFile = Join-Path $PSCredentialVault (Join-Path $Domain $Username)
  Write-Verbose "Storing credentials for '$PSCredential' in '$CredentialsFile'"
  mkdir -Force $CredentialsFile.Directory -ea 0 | Out-Null

  $SecureString = $PSCredential.Password | ConvertFrom-SecureString

  $Credential = New-Object PSObject
  $Credential | Add-Member NoteProperty Username      $NetCredential.Username
  $Credential | Add-Member NoteProperty Domain        $NetCredential.Domain
  $Credential | Add-Member NoteProperty SecureString  $SecureString

  $Credential | Export-CliXml -Path $CredentialsFile -Force:$Force
}

