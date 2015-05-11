# Preparing VM templates prepared outside of vizor for userdata bootstrap

To prepare VMs that were created outside of vizor to include the userdata
bootstrap scripts, the following startup scripts are required to be copied
into the VM before a template is created from it.

Copy the following files from the razor winpe.task into the
``\ProgramData\firstboot`` directory on the target VM (create it if it does not
exist) and register ``Start-Bootstrap.cmd`` as a logon script using the
following command in powershell (note the `` ` `` line continuators at the end
of the line).

> Administrator desktop autologon is required for these scripts to work.

> The following assumes a node with ID 1234 was provisioned with the
> ``winpe.task``, substitute appropriately.

> If no node was provisioned previously, these files are not available for
> download via the web URLs depicted here and will have to be copied out of
> the razor-server's ``winpe.task`` directory directly
> (i.e. razor-server/tasks/winpe.task).

```
function mywget {
  [CmdletBinding()] Param(
    [URI] $Uri,
    [IO.FileInfo] $File
  )
  (New-Object Net.WebClient).DownloadFile(
      $Uri.AbsoluteUri,
      (Join-Path $File.Fullname $Uri.Segments[-1])
    )
}
mywget "http://vizor.example.com/svc/file/1234/Start-Bootstrap.cmd"          "c:\ProgramData\firstboot\"
mywget "http://vizor.example.com/svc/file/1234/Start-Bootstrap.ps1"          "c:\ProgramData\firstboot\"
mywget "http://vizor.example.com/svc/file/1234/Start-AsyncAsfDiscovery.ps1"  "c:\ProgramData\firstboot\"
mywget "http://vizor.example.com/svc/file/1234/Set-CADIFirewall.ps1"         "c:\ProgramData\firstboot\"

reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"  `
  /f /v "${Env:SystemDrive}\ProgramData\Start-Bootstrap.cmd"      `
     /d '%SystemDrive%\ProgramData\firstboot\Start-Bootstrap.cmd' `
     /t REG_SZ
```

# TODO

* These bootstrap scripts are framework specific and so require special 
  consideration for distribution.
