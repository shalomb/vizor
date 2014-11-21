# PowerShell

d:\setup.exe                                              ` 
  /INDICATEPROGRESS                                       `
  /UpdateEnabled                                          `
  /UIMODE='AutoAdvance'                                   `
  /SQLSYSADMINACCOUNTS='.\Administrator'                  `
  /SAPWD='***REMOVED***'                                    `
  /INSTANCENAME='MSSQLSERVER'                             `
  /NPENABLED=1                                            `
  /SQLSVCSTARTUPTYPE='Automatic'                          `
  /UpdateEnabled=0                                        `
  /ERRORREPORTING=0                                       `
  /SQMREPORTING=0                                         `
  /SQLSVCSTARTUPTYPE='Automatic'                          `
  /ISSVCStartupType='Manual'                              `
  /RSSVCStartupType='Manual'                              `
  /ASSVCSTARTUPTYPE='Manual'                              `
  /BROWSERSVCSTARTUPTYPE='Manual'                         `
  /SQLCOLLATION='Latin1_General_CI_AS'                    `
  /QS                                                     `
  /Action='Install'                                       `
  /FEATURES='SQL,RS'                                      `
  /ENU                                                    `
  /INSTANCENAME='MSSQLSERVER'                             `
  /TCPENABLED=1                                           `
  /NPENABLED=1                                            `
  /AGTSVCACCOUNT='NT AUTHORITY\Network Service'           `
  /SECURITYMODE='SQL'                                     `
  /IACCEPTSQLSERVERLICENSETERMS        

function Install-SQLServer2012 {
  [CmdLetBinding()]
  Param(
    [Parameter(Mandatory=$False)] [String] $IACCEPTSQLSERVERLICENSETERMS        
    [Parameter(Mandatory=$False)] [String] $SECURITYMODE='SQL'                           
    [Parameter(Mandatory=$False)] [String] $QS                                           
    [Parameter(Mandatory=$False)] [String] $INDICATEPROGRESS                             
    [Parameter(Mandatory=$False)] [String] $UpdateEnabled                                  
    [Parameter(Mandatory=$False)] [String] $UIMODE='AutoAdvance'                         
    [Parameter(Mandatory=$False)] [String] $SQLSYSADMINACCOUNTS='.\Administrator'        
    [Parameter(Mandatory=$True)]  [String] $SAPWD='***REMOVED***'                          
    [Parameter(Mandatory=$true)]  [String] $INSTANCENAME='MSSQLSERVER'                   
    [Parameter(Mandatory=$False)] [String] $NPENABLED=1                                  
    [Parameter(Mandatory=$False)] [String] $SQLSVCSTARTUPTYPE='Automatic'                
    [Parameter(Mandatory=$False)] [String] $UpdateEnabled=0                              
    [Parameter(Mandatory=$False)] [String] $ERRORREPORTING=0                             
    [Parameter(Mandatory=$False)] [String] $SQMREPORTING=0                               
    [Parameter(Mandatory=$False)] [String] $SQLSVCSTARTUPTYPE='Automatic'                
    [Parameter(Mandatory=$False)] [String] $ISSVCStartupType='Manual'                    
    [Parameter(Mandatory=$False)] [String] $RSSVCStartupType='Manual'                    
    [Parameter(Mandatory=$False)] [String] $ASSVCSTARTUPTYPE='Manual'                    
    [Parameter(Mandatory=$False)] [String] $BROWSERSVCSTARTUPTYPE='Manual'               
    [Parameter(Mandatory=$False)] [String] $SQLCOLLATION='Latin1_General_CI_AS'          
    [Parameter(Mandatory=$False)] [String] $Action='Install'                             
    [Parameter(Mandatory=$False)] [String[]] $FEATURES='SQL,RS'                            
    [Parameter(Mandatory=$False)] [String] $ENU                                          
    [Parameter(Mandatory=$False)] [String] $INSTANCENAME='MSSQLSERVER'                   
    [Parameter(Mandatory=$False)] [String] $TCPENABLED=1                                 
    [Parameter(Mandatory=$False)] [String] $NPENABLED=1                                  
    [Parameter(Mandatory=$False)] [String] $AGTSVCACCOUNT='NT AUTHORITY\Network Service' 
  ) 
  
  $CmdArgs = @()
}
