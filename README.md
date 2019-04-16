# About

`vizor` is a comprehensive toolset that builds upon
[PuppetLabs razor-server](https://github.com/puppetlabs/razor-server)
to automate the building of Window VMs & VM images from vanilla ISOs
using
[WinPE](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-intro)
on the following cloud platforms

- Xen Cloud Platform
- Citrix XenServer
- Apache CloudStack
- Citrix CloudPlatform

## Capabilities

* Orchestrate the building of single VMs or batches of (thousands) of VMs at a
  time using saved configurations i.e. keep the machine image catalogue
  regularly up-to-date.
* Discover and build a catalogue of Windows Installer ISOs (e.g. from a central
  CIFS/NFS share, etc) from which VMs can be built. ISOs _do not_ have to be
  copied locally and vizor can scale VM building to many thousands of ISOs
  (Windows versions, editions, langugages, etc) for datacenter needs.
* Manage multiple CloudStack/Xenserver farms as (reference) platforms on which
  VMs can be created (from ISOs) and then templated for distribution later.
* Manage catalogues of `boxes` from which VMs/VMImages can be built on any
  of the clouds/virtualization platforms known to vizor.
* A (relatively) well designed CLI interface with organized hierarchies of
  subcommands, help text, tab-completion, etc make working with `vizor` easy.
* Automated setup of the `vizor` components on a `debian` VM.
* Support building of Windows VMs for the following Windows editions
  * Windows XP
  * Windows Server 2003
  * Windows Vista
  * Windows Server 2008
  * Windows 7 (Pro, Enterprise)
  * Windows Server 2008 R2
  * Windows 8
  * Windows Server 2012
  * Windows 8.1
  * Windows Server 2016
  * Windows 10
* Allow for overlaying language packs on top of existing `box` definitions
  i.e. reuse base box definition with multiple different language overlays.
* Injection of a
  [Powershell Provisioning Abstraction](razor/task/winpe.task/nodeprep-full.seq.ps1.erb#L33)
  that is able to re-use functionality from PowerShell Modules and apply that
  to the machine in task/sequence form until the sequence is fully complete. The
  sequence application is idempotent and survives multiple reboots.
* Fully automated (and extensible) end-to-end provisioning of the windows OS
  using the Powershell Provisioning Abstraction.
  * Windows Base OS Installation
  * Language Pack Installations
  * i18n Settings
  * Timezone and NTP configuration
  * Windows Updates (Repeated)
  * KMS License Configuration
  * Windows Activation Configuration
  * Windows Defender Definitions Updates and Scans
  * Multiple DotNet Framework Installations
  * Paravirtualization Driver Installations
  * Screen Resolution Settings (For XenServer and/or Cloudstack/Xenserver)
  * Local User Account Management
  * (User Defined) Startup Script Injection
  * Disk Defragmenter Tasks
  * Group policy (non-domain joined) definitions
  * NGen Optimization of .Net images
  * Startup Tasks Management (Scripts, Services, etc)
  * VM Image Optimizations
  * BGInfo Settings

## Usage

Please refer to the [doc/](doc/) directory for extended documentation on
pre-requisites, installation and setup, usage, etc.

As the documentation is pandoc-generated HTML, it is best viewed offline
starting at the [index](doc/index.md).

## License
vizor VM builder

Copyright (C) 2012,  Shalom Bhooshi

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
