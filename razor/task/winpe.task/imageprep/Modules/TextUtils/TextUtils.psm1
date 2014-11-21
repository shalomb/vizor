# PowerShell Module TextUtils/TextUtils.psm1


Set-StrictMode -Version 2.0
Set-PSDebug -Trace 0
$ErrorActionPreference = "STOP"


ConvertTo-UnixFileFormat {
  [CmdletBinding()] Param (
    [Parameter(Mandatory=$True)]  [String] $InputFile
    [Parameter(Mandatory=$False)] [String] $OutputFile = $InputFile
  )

  $ByteArray = [Byte[]][Char[]](Get-Content $InputFile  -Delimiter "`0") | ?{ $_ -ne 13 }
  $ByteArray | Set-Content -Encoding Byte   $OutputFile -Force:$Force
}


ConvertTo-DosFileFormat {
  [CmdletBinding()] Param (
    [Parameter(Mandatory=$True)]  [String] $InputFile
    [Parameter(Mandatory=$False)] [String] $OutputFile = $InputFile
  )

  $ByteArray = [Byte[]][Char[]](Get-Content $InputFile  -Delimiter "`0") | ?{ $_ -ne 13 }
  $ByteArray | Set-Content -Encoding Byte   $OutputFile -Force:$Force
}
