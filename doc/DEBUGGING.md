# Debugging the WinPE Task

The WinPE task is set up to download a set of scripts and dependencies
for the main powershell sequence to be run. All configuration of the node
is done by a single sequence (i.e. `nodeprep.seq.ps1`)

# Debugging the rendering of the ruby (.erb) templates

Since the ruby templates (.erb) used by razor expand metadata
(e.g. `node.metadata['key']`) supplied by the user, templates can fail to
render or can be rendered in a way that they are not valid by the applications
using the output (e.g. Windows Installer, Sysprep, nodeprep.seq.ps1)

e.g To ensure `unattended.xml.erb` renders appropriately for the windows 
installer in the WinPE stage.

First determine the node ID using `razor nodes` or making note of the ID from 
the log output of the `vizor box build` command. And then request the template
from razor using any standard web client.

    # node_id here is 1332
    curl -ssfL 'http://vizor.example.com:8080/svc/file/1332/unattended.xml'

For this example, the output here has to be valid XML that the windows
installer can use.

The process works for any .erb templates in the razor task. However, as each
of these cater for different purposes during template create - the output
(and validity) matters to the use/context.

# Debugging nodeprep.seq.ps1

The file `nodeprep.seq.ps1` is run by the cmdlets in the `ImageMaintenance`
powershell module to execute the tasks defined the sequence.

Tasks in the sequence will fail on any unexpected/error conditions which in
turn cause the entire sequence to fail. Execution of the sequence pauses to
allow for inspection of the VM state.

The last error/exception output on the console pertains the output of the last task
run and would the first thing to examine to determine failure.
Most failures in running the sequence can be identified this way.

## Entering the imageprep shell

Start the image prep shell by running the following command in a
cmd/powershell window

    \ip.cmd

## Viewing the powershell transcript of `nodeprep.seq.ps1`

The output of every run of `nodeprep.seq.ps1` is logged in a powershell
transcript (logged under `%ProgramData%\imageprep\log`).

    Show-Transcript  # and select the last transcript (default)

The contents of the bottom of the file highlight the last problem encountered.
Once the problem is resolved, the sequence can be rerun to continue from
the last failed task.

    Resume-ImageMaintenance  # Simply rerun the sequence

or

    .\firstboot.cmd    # Downloads all files fresh run the razor server
                       # and starts Resume-ImageMaintenance

## Running a single task from the sequence

This is useful if the objective is to run a subset of the tasks from the 
entire sequence.

E.g. to run only those tasks that have windows_update in their name.

    $Tasks = Get-Task -Sequence nodeprep.seq.ps1 -stage 0 -filter 'windows_update'
    $Tasks | fl *
    $Tasks | Invoke-Task -Verbose  # -Force is needed if the task was previously run.

# Extending/Modifying nodeprep.seq.ps1 and its dependencies

Changes to nodeprep.seq.ps1 can be done directly to
`razor/task/winpe.task/nodeprep.seq.ps1`

On re-running, firstboot.cmd on the node, these changes will automatically
be downloaded and run.

However, if any of the modules used by nodeprep.seq.ps1 are updated, the zip
file that delivers these will need to be repackaged before `firstboot.cmd`
is run.

    cd razor/task/winpe.task/imageprep
    zip -r ../imageprep.zip ./

## Bootstrapping VM templates prepared outside of vizor

Copy the following files from the razor `winpe.task` into the
`\ProgramData\firstboot` directory on the target VM 
(create it if it does not exist).

* Start-Bootstrap.cmd
* Start-Bootstrap.ps1
* Start-AsyncAsfDiscovery.ps1
* Set-CADIFirewall.ps1
* Invoke-DefaultBootstrapScript.ps1.erb

And register `Start-Bootstrap.cmd` as a windows startup task using the following
command in a `cmd.exe` window.

     reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"  ^
         /f /v %SystemDrive%\ProgramData\Start-Bootstrap.cmd /t REG_SZ ^
         /d %SystemDrive%\ProgramData\firstboot\Start-Bootstrap.cmd
