# About .seq.ps1 files
A ``seq.ps1`` file is simply a powershell script that codifies an array of
array of hashtables. Invoking it in a powershell process simply returns this
datastructure down the steppable pipeline.

Conceptually, a sequence represents a collection of atomic image preparation
objectives grouped into individual stages which are a collection of individual
tasks. Achieving the systems desired state is accomplished by successfully 
executing all the stages in a sequence.

A sequence is NOT to be invoked directly but rather through the
``ImageMaintenance\Get-Task`` and ``ImageMaintenance\Invoke-Task``
function. Please refer to the help of the ImageMaintenance module
(``Get-Help about_ImageMaintenance``) for more details on how sequences or 
smaller subsets of them can be run.

> Several minor issues exist, please refer to the ISSUES/NOTES section below for details.

# Example of a minimal sequence

```
# Stage 1 - Hello World and Install DotNet 3.5
@(
  @{ name     = 'HelloWorld';
      script  = { Write-Host "Hello world!" };
      pre = 1; post = 1; },
  @{ name = 'HelloWorld Only If On Win7/2008R2 or greater';
      script = { Write-Host "Hello world from a newer OS!" };
      pre = { (Gwmi Win32_OperatingSystem).Version -ge 6.1 };
      post = 1; },
  @{ name = 'Install AD Certificate Service Only If On 2012 And WINS Not Installed';
      pre = {
        $Test1 = ((Gwmi Win32_OperatingSystem).Caption -ilike "2012")
        $Test2 = -not((Get-WindowsFeature WINS).Installed)
        $Test1 -and $Test2                # test conditions to decide if 'script' can be run
      };
      script = {
        # Is a regular powershell script block
        # any code executable by powershell can go here.
        ipmo ServerManager; Add-WindowsFeature AD-Certificate 
      };
      post={ rm -Force "$Env:TEMP\*" };   # Failures here are not fatal
  }
  @{ name='InstallDotNet35andCleanup';
      script={ Import-Module ServerManager; Add-WindowsFeature NET-Framework-Features };
      pre=1;
      post= { rm -Force "$Env:TEMP\*" }; }
  @{ name='RebootToEnterStage2';
      script={ & shutdown.exe -r }; pre=1; post=1; },
),

# Stage 2 - Install some software
@(
  @{ name='Sync Windows Time';
      script={ & w32tm.exe /resync }; pre=1; post=1; },
  @{ name='InstallSoftwareOffANetworkShare';
      script={ \\example.com\share\software\someinstaller.exe -args };
      pre={ & ipconfig.exe /flushdns };  # This may fail but is harmless
      post=1;
   }
  @{ name='RebootToEnterStage3'; script={ & shutdown.exe -r }; pre=1; post=1; },
),

# Stage 3 - ClearLogs and shutdown
@(
  @{ name='ClearEventViewerEvents';
      script = { Get-EventLog -LogName * | %{ Clear-EventLog -LogName $_.Log } };
      pre = 1; post = 1; }
  @{ name='ShutDownComputerToPrepareForDeployment';
      script={ & shutdown.exe -s }; pre=1; post=1; }
)
```

# Anatomy of a sequence
A sequence is expected to return a powershell object to the caller and
not execute code to change the state of the system itself.

The engine to consume these sequences is usually ``ImageMaintenance\Get-Task``
but can be any powershell construct that understands the datastructure.

The runner is ``ImageMaintenanace\Invoke-Task`` which takes a pipelined
object from ``Get-Task``.

A sequence is defined as a collection of stages. It is represented as
an array of arrays (stages).

A stage is defined as a collection of tasks. It is represented as an
array of hashes (tasks).

A task is defined as an atomic activity. It is represented as a
hash table with powershell scriptblocks for values.

As a whole, the sequence is represented as an array of arrays of hashes.

This datastructure allows for the script to contain a set of stages,
each of which has a collection of tasks to be run in that stage.
This datastructure also allows for filtering on tasks to be run.

All tasks within a stage must pass for a stage to completed.

All stages must pass for the sequence to be complete (and so for the
image preparation to be complete).

A task is represented here hash with a 'script' key contain the
powershell scriptblock which contains the powershell cmdlets that will carry
out the task - and so effect change in the system. A 'script' should fail
if it cannot successfully execute the enclosing scriptblock - and so cause the
sequence to fail early.

A task also has other keys 'pre' and 'post' which are also scriptblocks
which control code executed before/after the 'script' key is invoked.

Code in the 'pre' block act as conditionals to the 'script' block i.e.
to allow or deny a 'script' block execution. If the 'pre' scriptblock
fails or throws an error, the 'script' scriptblock is not executed but
the sequence continues.

'post' encloses a scriptlet used to carry out clean-up tasks or seal the
state of the system - also in a failsafe fashion. Failures are not fatal
to sequence exeuction.

'pre' and 'post' are currently required to be defined and must have a
minimum value of $True or 1. They cannot be ommitted as optionals.

# Rationale of sequence breakdown
A collection of tasks can be written as a simple powershell script that
has the powershell interpreter step through the script and invoke the
tasks but this approach has a number of problems and limitations.

* It is necessary to accommodate for interruptions (reboots) or failures
  in executing (often long-running) tasks in a sequence and ensure that
  sequence execution resumes from the appropriate point (next task to be run)
  in the sequence.
  (i.e. supporting this in a traditional powershell script involves repeated
  complexity).

* It is hard to report on the state/status of individual tasks without
  wrapping each task up in a reporting function.

* Ensuring idempotency of a task hard to guarantee when the script is
  rerun. A subsequent invocation of a task can be unsafe or dangerous.
  i.e. Tasks determined to have previously run can be filtered out.

* Building logic in the script to filter out tasks for a particular
  objective or invocation becomes quite complex.

As the datastructure in a sequence such as this is just a collection of
objects, an orthogonal mechanism such as a task processor can be used to
process an object collection to easily address/mitigate the above problems.

> TODO: The objectives of post-install sequences overlaps with objectives of
> desired state configuration management systems such as OpsCode Chef,
> Puppet, PowerShell DSC. Consider moving to those to drive configuration.

# Known issues

A bug exists currently where if the number of elements in the sequence array
is less than 2, ``ImageMaintenance\Get-Tasks`` will fail to process this sequence
file. To workaround, simply create another empty element at the end of the
collection.
