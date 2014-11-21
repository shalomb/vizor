function Get-DecryptedString
{
  param
  (
   $thumbprint, 
   $encryptedpassword
  )

  $cert = ls cert:\localmachine\my\$thumbprint

  if($cert.PrivateKey -eq $null) 
  {
    throw "Certificate $thumbprint doesn't have a private key"
  }

  $encryptedData = [Convert]::FromBase64String($encryptedpassword)
  [reflection.assembly]::LoadWithPartialName("System.Security") | Out-Null
  $env = New-Object Security.Cryptography.Pkcs.EnvelopedCms
  $env.Decode($encryptedData)
  $env.Decrypt($cert)
  $enc = New-Object System.Text.ASCIIEncoding

  return $enc.GetString($env.ContentInfo.Content)   
}

Function New-X509Certificate
{
  param
  (
   [Parameter(Mandatory=$true)]
   [string]
   $CN,
   [switch] $MachineContext = $true,
   [switch] $ExportablePrivateKey,
   $KeyLength = 2048,
   $ExpiresInDays = 90,
   [ValidateSet(1,2,3)]
   [int] $PrivateKeyContext = 2 # Install private key to machine ctx 
  )

  Write-Host "Create certificate with X509Enrollment com object"

  if($KeyLength -lt 2048)
  {
    throw "Key length should be at least 2048"
  }

  $name = new-object -com "X509Enrollment.CX500DistinguishedName.1"
  $name.Encode($cn, 0)

  $key = new-object -com "X509Enrollment.CX509PrivateKey.1"
  $key.ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
  $key.KeySpec = 1
  $key.Length = $KeyLength
  $key.ExportPolicy = [int]$ExportablePrivateKey.IsPresent # make private key expotable http://msdn.microsoft.com/en-us/library/aa379002(v=vs.85)
  $key.KeyUsage = 16777215 # all usages

  # key will be stored in local machine certificate store
  $key.MachineContext = [int]$MachineContext.IsPresent
  $key.Create()

  $cert = new-object -com "X509Enrollment.CX509CertificateRequestCertificate.1"

  $cert.InitializeFromPrivateKey($PrivateKeyContext, $key, "")
  $cert.Subject = $name
  $cert.Issuer = $cert.Subject
  $cert.NotBefore = (get-date).Subtract([TimeSpan]::FromDays(1))
  $cert.NotAfter = $cert.NotBefore.AddDays($ExpiresInDays)

  Write-Host $ExpiresInMonths
  Write-Host $cert.NotAfter

  $cert.Encode()

  $enrollment = new-object -com "X509Enrollment.CX509Enrollment.1"
  $enrollment.InitializeFromRequest($cert)
  $certdata = $enrollment.CreateRequest(0)
  $enrollment.InstallResponse(2, $certdata, 0, "")

  return $certdata
}


Function Get-CertificateBase64
{
  param
  (
   [Parameter(Mandatory=$true)]
   [string]
   $Thumbprint
  )

  Write-Verbose $Thumbprint
  $cert = ls cert:\localmachine\my\$Thumbprint
  Write-Verbose $cert
  $bytes = $cert.Export("Pkcs12")

  $base64Str = [Convert]::ToBase64String($bytes)

  Write-Output $base64Str
}

