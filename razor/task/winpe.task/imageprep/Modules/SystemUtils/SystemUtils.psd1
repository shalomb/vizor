@{
  ModuleToProcess          = 'SystemUtils'
    Description            = 'Utilities for dealing with the Windows Operating System.'
    ModuleVersion          = '1.0'
    GUID                   = '35265bf5-9113-416e-8276-a23ec47e360c'
    Author                 = 'Shalom Bhooshi <shalom.bhooshi@citrix.com>'
    CompanyName            = 'Citrix Systems'
    Copyright              = '(c) 2013, Citrix Systems Inc.'
    PowerShellVersion      = '2.0'
    # RequiredModules         = @('ModuleUtils')
    # ScriptsToProcess        = @('Register-Dependencies.ps1')
    ModuleList              = @(
      @{  ModuleName        = 'TaskUtils';
          ModuleVersion     = '1.0.0.0';
          GUID              = '674ddc20-babc-11e4-9159-0022191753d4';
      },
      @{  ModuleName        = 'DotNetFramework';
          ModuleVersion     = '1.0.0.0';
          GUID              = 'eb090a04-babb-11e4-aafd-0022191753d4';
      }
    )
    AliasesToExport        = '*'
    CLRVersion             = ''
    CmdletsToExport        = '*'
    DotNetFrameworkVersion = ''
    FileList               = @()
    FormatsToProcess       = @()
    FunctionsToExport      = '*'
    NestedModules          = @()
    PowerShellHostName     = ''
    PowerShellHostVersion  = ''
    PrivateData            = ''
    ProcessorArchitecture  = ''
    RequiredAssemblies     = @()
    TypesToProcess         = @()
    VariablesToExport      = '*'
}
