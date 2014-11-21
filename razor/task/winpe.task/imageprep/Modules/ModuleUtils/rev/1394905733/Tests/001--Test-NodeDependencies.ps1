Set-StrictMode -Version 2.0

$Available = @{
  "Foo"     = ( New-Node -Name "Foo"    -Edges @( 
        @{ "Bar" = @{ Version="1.1"; Guid="bcab57b1-1f22-4ad2-9007-7cb0ab4c86c1"; }; },
        @{ "Baz" = @{ Version="1.1"; Guid="bcab57b1-1f22-4ad2-9007-7cb0ab4c86c1"; }; }
        ) 
      );
  "Bar"     = ( New-Node -Name "Bar"    -Edges @( 
        @{ "Baz"    = @{ Version="1.1"; Guid="bcab57b1-1f22-4ad2-9007-7cb0ab4c86c1"; }; },
        @{ "Fred"   = @{ Version="1.1"; Guid="bcab57b1-1f22-4ad2-9007-7cb0ab4c86c1"; }; }
        @{ "Gee"    = @{ Version="1.1"; Guid="bcab57b1-1f22-4ad2-9007-7cb0ab4c86c1"; }; }
        ) 
      );
  "Baz"     = ( New-Node -Name "Baz"    -Edges @( ) );
  "Fred"    = ( New-Node -Name "Fred"   -Edges @( "Grault", "Waldo" ) );
  "Qux"     = ( New-Node -Name "Qux"    -Edges @( "Bar" ) );
  "Grault"  = ( New-Node -Name "Grault" -Edges @( ) );
  "Waldo"   = ( New-Node -Name "Waldo"  -Edges @( "Baz", "Grault" ) );
  "Gee"     = ( New-Node -Name "Gee"    -Edges @( ) );
}

$Available
exit
Get-NodeDependencies `
  -AvailableSelections $Available `
  -Node $Available["Foo"] -Verbose

