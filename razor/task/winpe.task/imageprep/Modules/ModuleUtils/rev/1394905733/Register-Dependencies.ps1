Import-Module PSDUtils

if ($ThisModuleManifestFile = Find-ModuleManifestFile) {
  if ($Manifest = Read-PSDFile -Path $ThisModuleManifestFile) {
    $Manifest.ModuleList | %{
      Write-Host -Fore Cyan "Import-Module -Name $_"
      Import-Module -Name $_
    }
  }
} 
else {
  Write-Warning "No Module Manifest found for script '$($MyInvocation.Command)'"
}
