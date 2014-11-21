# powershell


# Import Modules Here


@(
  @{ name    =   'do_on_2008';
      script = { Write-Host "We're on Win 2008" };
      pre    = { $os = gwmi win32_operatingsystem; if (-not($os.version -imatch '^6.2')){ Write-Warning 'Not on Windows 2008' } };
      post   = { 1 }; }
  @{ name    =   'do_on_win7';
      script = { Write-Host "We're on Win 7" };
      pre    = { $os = gwmi win32_operatingsystem; $os.version -imatch '^6.1' };
      post   = { 1 }; }
  @{ name    =   'rename_computer';
      script = { Write-Host "Set ComputerName" };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'join_comain';
      script = { Write-Host: "DomainName" };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'reboot_computer';
      script = { Stop-Computer };
      pre    = { 1 };
      post   = { 1 }; }
),

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

