# TODO : ModuleUtils ought to install these automatically


$TargetDir = if ($Env:PROGRAMDATA) {$Env:PROGRAMDATA} else {Join-Path "$Env:SYSTEMDRIVE" "ProgramData"}
$TargetDir = Join-Path $TargetDir "Citrix\PowerShell\Modules\"
mkdir $TargetDir -Force | Out-Null
'CDRom','XenTools','VMGuestTools','HyperVIC','VMWareTools','ModuleUtils','SystemUtils' | %{
  cp -Verbose -Recurse -Force "$Env:IPBaseDir\Modules\$_\" "$TargetDir"
}

& "$TargetDir\VMGuestTools\Tests\Install-VMGuesttools.ps1" -SelfInstall

disable-clearpagefileatshutdown -verbose
rm c:\onelab\bin\install*guest*cmd -ea 0
sleep 2
restart-computer
