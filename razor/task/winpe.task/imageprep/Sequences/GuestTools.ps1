# powershell


$Env:OLBASE = "C:\OneLab"
$Env:OLMOD  = Join-Path $Env:OLBASE "Modules"
$Env:OLCONF = Join-Path $Env:OLBASE "conf"
$Env:OLBIN  = Join-Path $Env:OLBASE "bin"
$Env:OLLOG  = Join-Path $Env:OLBASE "log"
$Env:OLIP   = Join-Path $Env:OLLOG  "ImagePrep"


@(
  @{ name    =   'install_xentools_modules';
      script = { 
        'Modules/XenTools','Modules/CDRom' | %{
          cp -Recurse -Force -Verbose (Join-Path $Env:IPBaseDir $_) (Join-Path $Env:OLBASE 'Modules') 
        }
      };
      pre    = { 1 };
      post   = { 1 }; }
)


@(
  @{ name    =   'install_xentools_installer';
      script = { 
        "$Env:PSModulePath += ';$Env:OLMOD'"
        "Import-Module XenTools -Verbose"
        ""
      };
      pre    = { 1 };
      post   = { 1 }; }
)


# vim:sw=2:ts=2:et:foldexpr=getline(v\:lnum)=~'^\\s*$'&&getline(v\:lnum-1)=~'^\\s*$'&&getline(v\:lnum+1)=~'\\S'?'<1'\:1:fdm=expr:filetype=ps1:ff=dos:fenc=ASCII

