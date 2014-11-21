#AsfShell Bootstrap

if (Get-Module -ListAvailable | ?{$_.Name -eq "Asf"}) {
    Import-Module Asf
} 
else {
  cd $Env:SystemDrive
  iex((New-Object Net.WebClient).DownloadString('http://camautonfs01.eng.citrite.net/asf/irtt'))
}