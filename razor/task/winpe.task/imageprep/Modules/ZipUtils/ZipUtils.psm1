Set-StrictMode -Version 2


function Out-Zip {
  [CmdletBinding()]
  Param(
    $zipfilename, 
    $sourcedir
  )

    [Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" )
    $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
    [System.IO.Compression.ZipFile]::CreateFromDirectory( $sourcedir, $zipfilename, $compressionLevel, $false )
}
