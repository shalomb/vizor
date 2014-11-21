Itemization
-----------

Bootstrap-PowerShell-2.0.cmd  - Bootstrap and install PowerShell 2.0 on XP/2003, Vista/2008
Install-Xentools.cmd          - Wrapper around Invoke-ImagePrep.cmd that calls Install-XenTools
Invoke-ImagePrep.cmd          - Takes a ImagePreparation task to run or launches the IP shell
Invoke-StartupTasks.cmd       - Startup Tasks runner run within SUT
Invoke-StartupTasks.ps1       - Called from Invoke-StartupTasks.cmd, the actual engine
Import-ImageMaintenance.ps1   - Convenience script to import the ImageMaintenance module

CONFIG.cmd                    - Site configuration
Clone-Templates               - Bash script to clone templates
Inject-XSTools                - Bash script to inject xs-tools.iso into VMs
