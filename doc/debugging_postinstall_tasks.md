# Debugging the WinPE Task

The WinPE task is set up to download a set of scripts and dependencies
for the main powershell sequence to be run. All configuration of the node
to requirements is currently done by a single sequence (i.e. `nodeprep.seq.ps1`)

# Debugging the razor ruby (.erb) templates

To deliver per-node customizations to the ``nodeprep.seq.ps1`` sequence, a
set of ruby templates is contained in the ``winpe.task`` razor task. These
templates are evaluated by the ruby ([ERB](http://www.stuartellis.eu/articles/erb/))
templating engine which interpolates the JSON metadata blob passed in via
the vizor build scripts (i.e. ``vizor box build``, ``vizor batch build``, etc)

Since the ruby templates (.erb) used by razor expand metadata key/values
(e.g. `node.metadata['key']`) supplied by the user, templates can fail to
render against valid syntax or can be rendered in a way that enclosed data is
not valid for the applications that use the output. Example of these processes
are the Windows Installer, Localization, Windows Sysprep, nodeprep.seq.ps1, etc.

e.g To ensure `unattended.xml.erb` renders appropriately for the various
[stages of windows setup](https://technet.microsoft.com/en-gb/library/cc749307(v=ws.10).aspx)

First determine the node ID using ``razor nodes`` or making note of the ID from 
the log output of the `vizor box build` command, then request the template
from razor using any standard web client.

    # 1332 in this example is the id of the razor node
    curl -ssfL 'http://vizor.example.com:8080/svc/file/1332/unattended.xml'

For this example, the output here has to be valid XML that the windows
installer can use. An XML validator can be used to validate the XML.

    xmllint --format unattended.xml  # must output valid XML and not error out

As each of these templates are inputs for different purposes during post-install
phase, their output (and validity) matters to the use/context.

i.e.

* nodeprep.seq.ps1.erb must render to valid [powershell object](about_sequences.html)
* l18n.xml.erb must render to valid [XML for localization/globalization](http://support.microsoft.com/kb/2764405)
* unattended.xml.erb must render to valid XML for [Windows Setup](https://technet.microsoft.com/en-us/library/cc766245(v=ws.10).aspx)
* sysprep.xml.erb must render to valid XML for [Windows sysprep](https://technet.microsoft.com/en-gb/library/hh824849.aspx)

and so on.

# Debugging nodeprep.seq.ps1

Refer to [About Post-Install Sequences](about_sequences.html) for 

The sequence of configuration tasks in ``nodeprep.seq.ps1`` is currently driven
by the cmdlets in the ``ImageMaintenance`` powershell module which execute these
tasks as individual powershell scriptblocks.

Tasks in the sequence may fail on any unexpected/error conditions which in
turn cause the entire sequence to fail. If the sequence fails to complete,
execution of the sequence is aborted to allow for inspection of the VM state
and for rectifications to be made before resuming (this requires manual
intervention).

The error/exception output on the console pertains the last task run and would 
be the first thing to examine to determine cause of failure. Given the way the
sequence is set to ``STOP`` on first failure, this should be the only failure
encountered.

## Entering the imageprep shell

The ImagePrep shell is a powershell environment set up with the appropriate
``$Env:PATH`` and ``$Env:PSModulePath`` variables to make it easier to debug or
develop sequences.

Start the image prep shell by running the following command in a
cmd/powershell window

    c:\programdata\firstboot\Bootstrap\Invoke-Imageprep.cmd

an alias for the same script is provided at

    \ip.cmd

## Viewing the powershell transcript of `nodeprep.seq.ps1`

The output of every run of `nodeprep.seq.ps1` is logged in a powershell
transcript (logged under `%ProgramData%\imageprep\log`). To view the
transcripts available

    Show-Transcript  # and select the last transcript (default)

The contents of the bottom of the file highlight the last problem encountered,
i.e. towards the bottom of the transcript.

If the resolution involves no code-fix the sequence can be rerun to continue from
the last failed task by simply running

    Resume-ImageMaintenance  # Simply rerun the sequence

or if edits have been made to the code or sequences, then the code needs to be
pushed to vizor and razor. Refer to the [Extending Post-Install Tasks](extending_postinstall_tasks.html)
document on how to prepare vizor and the razor ``winpe.task`` for this.

    .\firstboot.cmd    # Downloads all files fresh run the razor server
                       # and starts Resume-ImageMaintenance

## Running a single task from the sequence

This is useful if the objective is to run a subset of the tasks from the
entire sequence e.g. rerunning a particular task or developing a new task to
incorporate into the sequence.

E.g. to run only those tasks that have windows_update in their name.

    $Tasks = Get-Task -Sequence nodeprep.seq.ps1 -stage 0 -filter 'windows_update'
    $Tasks | fl *
    $Tasks | Invoke-Task -Verbose  # -Force is needed if the task was previously run.

