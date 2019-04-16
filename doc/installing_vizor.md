# Installing vizor

## Preparation

### Requirements for the vizor host

A host or VM with the following requirements

* Debian "wheezy" 7.x vanilla installation
* 4 GB RAM (8 GB recommended if building > 20 VMs concurrently)
* 2 vCPUs (4 vCPUs recommended if building > 20 VMs concurrently)
* 8 GB disk space for root volume
* 1 Gbps link to network directory hosting install ISOs.

> If performing installs for a large number of VMs, it is advisable to
> ensure sufficient bandwidth between the vizor host and the ISO repositories
> otherwise the build times of all VMs is affected adverself.

> Partitioning network traffic across separate links may also be needed to ensure
> that vizor's access to the ISO repository is kept on a separate network segment
> to the distribution of the install images to VMs being built.

> If ISOs are copied to the vizor host for it to use as a local repository
> sufficient disk space is needed to store those.

Additionally these configurations are needed to the vizor host

* [Hostname set](http://www.debianhelp.co.uk/hostname.htm)
* [Hostname/FQDN registered in DNS](http://www.tomshardware.co.uk/faq/id-1954305/adding-dns-host-record-windows-server-2012-dns-server.html)

### Infrastructure Requirements

* DHCP Services to address VMs being built
* DNS resolution of the vizor host
* A fully setup cloudstack or xenserver pool

### Optional Infrastructure Requirements

* A WSUS Server URL with appropriate WSUS profiles to speed up/control windows updates.
* A KMS Server if nodes do not derive this from DNS service records.
* An NTP/sNTP Server for time services if not handled by DHCP.

### Pre-setup tests

#### Hostname resolution

    hostname      # hostname
    hostname -s   # short hostname
    hostname -f   # FQDN

#### DNS resolution of the vizor host's FQDN

    nslookup vizor.example.com dnsserver.example.com

#### Test mount the network share containing ISOs

    mount -t cifs //mycifserver.example.com/isos /mnt/isos \
      -o username=accessuser,password=S3cr3t,domain=example.com

    find /mnt/isos

### Building WinPE (.wim) images

The following steps require a machine running Windows 8.1 or
Windows Server 2012 R2 with about 1GiB of space.

Download the [Windows Assessment and Deployment Kit (Windows ADK) for Windows 8.1](https://www.microsoft.com/en-gb/download/details.aspx?id=39982) and install the WinPE components using this powershell command.

    mkdir -force c:\programdata\adk
    adksetup.exe /quiet /installpath c:\programdata\adk `
      /features OptionId.WindowsPreinstallationEnvironment `
                OptionId.DeploymentTools `
      /norestart /log c:\ProgramData\adk\setup.log

Two WinPE images are generated under ``c:\programdata\adk\*\*.wim``,
a 32 and 64 bit image. These should be [copied](http://winscp.net/eng/docs/task_upload)
into the vizor host (/usr/src recommended) as these are required by the 
``setup`` commands in the next steps.

## Installation

> When using Perfoce, ensure the workspace is set for 
> [unix-style line endings](http://answers.perforce.com/articles/KB/3096)
> to ensure that the setup scripts are untainted and can be executed successfuly.

Sync down the vizor source on to a suitable workspace and then mirror
the directory to ``/usr/src/vizor`` on the vizor host and then invoke the 
setup.

    source /usr/src/vizor/lib/completion.sh
    vizor setup vizor -w -c

The script prompts for data about razor passwords, locations to WinPE
images, etc and will manage the installation and configuration of all the 
components needed by vizor. This process takes about ~20 minutes.

Upon successful completion, vizor is ready to begin building VMs. 
Please refer to the [Building VMs](building_vms.md) document for
a guide and how-to.

# Known Issues and Mitigations

## iPXE does not successfully hand-off to razor on XenServer 6.5

On XenServer 6.5 (this includes XenServer when used as a manager hypervisor
under CloudStack/CloudPlatform, etc), iPXE isos built by vizor may not boot
and hand-off provisioning to razor. This is a known upstream issue and a fix
is expected in a future XenServer 6.5 hotfix or ipxe revision.

To work around the issue, build the iPXE iso using the XenServer iPXE repository.

    cd /usr/src
    aptitude install build-essential
    git clone git://hg.uk.xensource.com/carbon/creedence/ipxe.git
    cd ipxe/src
    wget -q "http://myvizor.dns.domain:8080/api/microkernel/bootstrap" -O bootstrap.ipxe
    make clean
    make
    make bin/ipxe.iso EMBED="$PWD"/bootstrap.ipxe
    cp -a bin/ipxe.iso /var/www/ipxe/

## razor client uses incorrect port when communicating with server API

To work around several issues in the past and keep the razor client up to date,
it is installed directly from the master branch upstream. A breaking change
means that the client now talks to the razor-server on port 8081 or similar
while razor-server's API is set to listen on TCP port 8080.

Several vizor build scripts are affected and yield unexpected results.

To verify if the client needs to be updated, test it with

    unset RAZOR_API

    root@stage-vizor:~# razor -d nodes
    Error: Could not connect to the server at http://localhost:8081/api
           Connection refused - Connection refused

The workaround until a fix can be introduced is to set the RAZOR_API environment
variable to use port 8080.

    export RAZOR_API='http://localhost:8080/api'

    root@stage-vizor:~# RAZOR_API=http://localhost:8080/api
    root@stage-vizor:~# razor -d nodes
    GET http://localhost:8080/api
    ...

This can be made permanent across all future shells with an addition to
``~/.bashrc``.

    echo "export RAZOR_API='http://localhost:8080/api'" >> ~/.bashrc


