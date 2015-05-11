# Setting up vizor

This guide contains instructions on setting up a vizor server.

# Prerequisites

* A Debian machine (version 7/Wheezy), 64-bit install
* 2 VCPUs Minimum, 4 Recommended
* 4 GiB RAM Minimum, 8 Recommended
* 1 Gigabit Ethernet, 2 Interfaces recommended (see Network Setup Notes below)

# Setup the vizor server hostname

    echo myvizor > /etc/hostname
    echo '10.70.200.2  myvizor.dns.domain myvizor' >> /etc/hosts
    hostname myvizor
    /etc/init.d/hostname.sh

Test hostname resolution

    hostname
    hostname -f

# Make an A record for the vizor server in DNS

    VMs use DNS in resolving the vizor server. This step is important.


In the DNS zone the server is in (e.g. dns.domain) - create a new A record.

Test out DNS resolution of the vizor server from a remote host

    nslookup myvizor.dns.domain

# Get Vizor

    If syncing the code out onto a Windows machine, it is recommended that a new workspace be setup with the line endings set to ``unix``

Sync the code out of perforce and copy the source tree to /usr/src/vizor on the vizor server.

# Build WinPE images

The WinPE images are needed for razor's second stage for WinPE. WinPE images of both architectures (32 and 64 bit) are needed.

Download the Windows 8 ADK onto a Windows 8/2012 R2 machine and run the following command.

    adksetup.exe /quiet /installpath C:\ProgramData\adk `
        /features OptionId.WindowsPreinstallationEnvironment OptionId.DeploymentTools `
        /norestart /log c:\ProgramData\adksetup.log

Refer to the 'ADKSetup Command Line Syntax' https://technet.microsoft.com/en-us/library/dn621910.aspx for options on setting up the ADK.

# Setup vizor

Copy the generated WinPE .wim files from the Windows 8/2012 machine to to /usr/src/ on the vizor server and run the following commands

    source /usr/src/vizor/lib/completion.sh

    export WINPE_X86_WIM=/usr/src/winpe-x86.wim
    export WINPE_X86_64_WIM=/usr/src/winpe-x86_64.wim
    export RAZOR_DB_PASSWORD=p455w0rd
    vizor setup vizor -w -c

Upon completion of the above, the vizor server should be setup and ready for use. To start using vizor, refer to the USAGE document.

# ISSUES

* On XenServer 6.5 (this includes XenServer when used under CloudStack/CloudPlatform), iPXE isos built by vizor may not boot and hand-off provisioning to razor. This is a known issue and a fix is expected in a XenServer 6.5 hotfix. To work around the issue, build the iPXE iso using the XenServer iPXE repository.

    cd /usr/src
    git clone git://hg.uk.xensource.com/carbon/creedence/ipxe.git
    cd ipxe/src
    wget -q "http://myvizor.dns.domain:8080/api/microkernel/bootstrap" -O bootstrap.ipxe
    make clean
    make
    make bin/ipxe.iso EMBED="$PWD"/bootstrap.ipxe
    cp -a bin/ipxe.iso /var/www/html/ipxe/
