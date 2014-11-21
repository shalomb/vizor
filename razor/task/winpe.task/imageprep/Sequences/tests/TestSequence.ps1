
# Stage 1
@(
  @{ name    =   'hello_world';
      script = { hostname.exe };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'hello_world_2';
      script = { cmd /c "echo hello world && exit 37" };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'hello_world_3';
      script = { throw "foo" };
      pre    = { 1 };
      post   = { 1 }; }
),
# Stage 1
@(
  @{ name    =   'restart_computer';
      script = { Restart-Computer };
      pre    = { 1 };
      post   = { 1 }; }
),
# Stage 1
@(
  @{ name    =   'set_timezone';
      script = { 
        Write-Host "Enter timezone:"; 
        $foo = Read-Host; 
        "Timezone  was $foo"  
        Get-TimeZone | ?{ $_.Id -imatch $foo } | Set-Timezone -verbose
      };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'hello_world_3';
      script = { Write-Host -Fore Green "Hello world!!" };
      pre    = { 1 };
      post   = { 1 }; }
  @{ name    =   'print_hostname';
      script = { $Env:COMPUTERNAME };
      pre    = { 1 };
      post   = { 1 }; }
)
