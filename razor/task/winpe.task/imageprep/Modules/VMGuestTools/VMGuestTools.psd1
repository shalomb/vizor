@{
  ModuleToProcess           = 'VMGuestTools'
    Author                  = 'Citrix Systems'
    CompanyName             = 'Citrix Systems Inc.'
    Copyright               = '(c) 2013, Citrix Systems Inc.'
    Description             = 'Support for Hypervisor Virtual Machine Tools.'
    GUID                    = '5ee0c1bc-f1fc-463d-b417-6d3e6f23d4b8'
    ModuleVersion           = '1.1.0.0'
    PowerShellVersion       = '2.0'
    RequiredModules         = @('ModuleUtils')
    ScriptsToProcess        = @('Register-Dependencies.ps1')
    ModuleList              = @(
      @{  ModuleName        = 'XenTools';
          ModuleVersion     = '1.0.0.0';
          GUID              = '8d22586c-1501-48ad-897d-c1b5988d21bc'
      },
      @{  ModuleName        = 'VMWareTools';
          ModuleVersion     = '1.0.0.0';
          GUID              = '27f3dc84-cbde-430a-be21-3841a5db5801'
      },
      @{  ModuleName        = 'HyperVIC';
          ModuleVersion     = '1.0.0.0';
          GUID              = '8346f5e1-a051-43e5-9a4c-2eab8916f788'
      },
      @{  ModuleName        = 'CDRom';
          ModuleVersion     = '1.0.0.0';
          GUID              = '71df0f2f-2cef-4f55-a246-c8b8f89046a6'
      }
    ) 
    AliasesToExport         = '*'
    CLRVersion              = ''
    CmdletsToExport         = '*'
    DotNetFrameworkVersion  = ''
    FileList                = @()
    FormatsToProcess        = @()
    FunctionsToExport       = '*'
    NestedModules           = @()
    PowerShellHostName      = ''
    PowerShellHostVersion   = ''
    PrivateData             = ''
    ProcessorArchitecture   = ''
    RequiredAssemblies      = @()
    TypesToProcess          = @()
    VariablesToExport       = '*'
}


