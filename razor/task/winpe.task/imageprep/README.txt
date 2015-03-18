Use Case #1 - Complete preparation of a vanilla image
-----------------------------------------------------

Requirements
------------
You will need a sequence file modelled in the fashion of
  \\razor\ip\Sequences\StandardAsfImagePrep.ps1

Invocation Example
------------------
  * From the machine to be prepared, invoke the bootstrap script.

    PS> \\razor\ip\BootStrap\Invoke-ImagePrep.cmd

  * In the ImagePrep shell, invoke your sequence.

    PS> Resume-ImageMaintenance -Sequence \\path\to\your\seq.ps1

    # Or

    PS> cd \\path\to\your\imageprep;
    PS> # do something
    PS> # do something else
    PS> Resume-ImageMaintenance -Sequence YourSequenceFile.ps1

  * You may use your own sequence or the example provided to start stage 0.

    PS> Resume-ImageMaintenance -Sequence Sequences\StandardAsfImagePrep.ps1

  * Resume imagemaintenance to progress to the next stage
    (e.g. after an intermediate reboot)

    PS> Resume-ImageMaintenance
    # Note: you do not have to specify a path to -Sequence this time
    #       as this is already remembered from the previous stage.

  * Repeat the process until you've completed all stages.

  * Logs are kept in %SystemRoot%:\imageprep\ and can be shown with

    PS> Show-ImagePrepTranscript


Use Case #2 - Invoking a few select tasks to be run
---------------------------------------------------

This may be to do routine maintenance where only a few
steps from your sequence need to be run. e.g. to update windows,
inject a new bootstrap script, etc.

Requirements
------------
You will need a sequence file modelled in the fashion of
  \\razor\ip\Sequences\StandardAsfImagePrep.ps1

Invocation Example
------------------

  * Select the tasks to be run from a particular stage

    PS> $MyTasks = Get-Task -Sequence \\path\to\your\sequence.ps1 `
          -Stage 0 -filter 'windows.*update'

  * Run the tasks

    PS> $MyTasks | Invoke-Task

  * Logs are kept in %SystemRoot%:\imageprep\ and can be shown with

    PS> Show-ImagePrepTranscript
