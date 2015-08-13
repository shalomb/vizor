# Extending or Modifying the Post-Install Tasks

> It is recommended that changes to the code be made in a development workspace
> and then pushed to the vizor host via SSH, SCP or similar.

``nodeprep.seq.ps1`` consumes a set of PowerShell modules which contain the
implementations of CmdLets used in the provisioning tasks for this sequence.

Most changes to the in-VM provisioning logic occur in this file or its 
dependencies (PowerShell Modules, binaries, etc).

## Layout of the winpe.task directory
The following documents the layout of ``winpe.task``

    unattended.xml.erb    # Template for unattended.xml used by Windows Setup, also the entry-point for post-install processing.
    firstboot.cmd         # Wrapper around firstboot.ps1, called from unattended.xml 
    firstboot.ps1         # Main powershell provisioner script that sets up the environment before invoking nodeprep.seq.ps1
    nodeprep.seq.ps1.erb  # Template for nodeprep.seq.ps1, main sequence that drives all the post-install configuration on the node.
    Install-Prerequisites.ps1.erb # Script that downloads and refreshes the local layout of the files in winpe.task from the razor server
    sysrep.xml.erb        # Template for sysprep.xml, is a subset of unattended.xml, used by the sysprep task(s)
    l18n.xml              # Template for localization (l18n) and locale/location task(s)
    metadata.ps1.erb      # Template for metadata.ps1.erb, contains all razor metadata expanded for use on the node.
    ...
    imageprep/bin/        # Container for binaries needed on the end-point e.g. Sysinternals binaries, Set-Resolution, etc
    imageprep/conf/       # Configuration files for distributed binaries
    ...
    imageprep/Modules/    # Container for the PowerShell module hierarchy
    imageprep/Modules/WindowsUpdate/WindowsUpdate.psm1
    imageprep/Modules/SystemUtils/SystemUtils.psm1
    ...
    Start-BootStrap.cmd   # Script that is registered as a logon script in SUTs to begin bootstrap processing
    Start-BootStrap.ps1   # Main powershell implementation of bootstrap processing
    Start-AsyncAsfDiscovery.ps1  # Multicast discovery script for ASF bootstrap (where userdata is not available).
    Set-CADIFirewall.ps1  # Script to set the VM up for CADI bootstrap if all other bootstrap fails

Changes to the files will be picked up on the PowerShell processes running on
the node end-point when the ``winpe.task`` is updated and ``firstboot.cmd`` is
(re)run, emulating the process flow when Windows Setup completes.

> Note, the sequence may not process a task if it has previously been run and
> succeeded. So changes to any of the above files require that the containing
> tasks be re-run and/or forced.

## Updating winpe.task

The staging point for the above layout that serves files to be executed on nodes is
``/usr/src/razor-server/tasks/winpe.task`` and therefore changes made under
``/usr/src/vizor/razor/task/winpe.task`` will need to be verified and then
mirrored to the staging point when approved.

On the vizor server

    cd /usr/src/razor-server/task/winpe.task/
    rsync -avP /usr/src/vizor/task/winpe.task/ ./   # Changes from the /usr/src/vizor/ winpe.task overwrite those under /usr/src/razor-server/
    ( cd imageprep/ && zip -r ../imageprep.zip ./ ) # Subshell creates a new zip file of the imageprep/ directory


On the node being prepared

    cd \ProgramData\firstboot
    .\firstboot.cmd

## Automatically keeping winpe.task in sync

If setting up vizor for prolonged development, then running the above commands
may become repetetive and error-prone. The following directory watcher can be
setup to automatically trigger those commands on any file changes (recursively)
under the ``razor-server/tasks/winpe.task`` directory.

```
aptitude install inotify-tools

watch_mirror ()  {
  local src="$1";
  local dst="$2";
  inotifywait -r -m --format "%e %w" -e moved_to "$src" |
    while read event file; do
      rsync -avP "$src/" "$dst/";
      ( cd /usr/src/razor-server/tasks/winpe.task/imageprep/ && zip -r ../imageprep.zip ./ );
    done;
}

watch_mirror /usr/src/vizor/razor/task/winpe.task/ /usr/src/razor-server/tasks/winpe.task/
```

