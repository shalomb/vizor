# About Vizor

vizor is a provisioning tool that builds on top of PuppetLabs Razor to assist in performing network installs of virtual machine images.

## Features

    * Building rich OS install image catalogs from ISOs on fileservers (currently windows only)
    * Orchestrate Windows OS Unattended Installs by mounting and exposing ISOs (ISOs are not copied to staging area).
    * Creation of customizable Virtual Machine Containers on CloudStack and XenServer.
    * Creation and publication of VM/Instant Templates.
    * Support for installation of PV/Guest Tools from VM ISOs.
    * Installation of Language Packs (Windows Only) for Partially Localized OSes.
    * Support for custom provisioner sequence (PowerShell Based).
    * Catalog of VM instances, templates, 

# Install

vizor must be run in a dedicated debian virtual machine - it is not designed to run on an existing host and will likely break/interfere with existing apache or samba installs.

## Hardware Requirements

    * 2 VCPUs Minimum, 4 Recommended
    * 4 GiB RAM Minimum, 8 Recommended
    * 1 Gigabit Ethernet, 2 Interfaces recommended (see Network Setup Notes below)

## Installation

Copy the contents of the vizor source to /usr/src/vizor/ on your appliance.

    source /usr/src/vizor/lib/completion.sh
    aptitude update
    vizor setup vizor

## Usage

Refer to the USAGE document.

## Debugging

Refer to the DEBUGGING document.

## Network Setup

The virtual machine that vizor is installed into must have access to the API services of your CloudStack/CloudPlatform or XenServer (XAPI) management servers. In addition, it must have decent network access and bandwidth to the file servers hosting the OS ISOs - though these ISOs are not copied to the vizor server, vizor will mount these ISOs and expose the contents to the OS setup programs. As the install images copied down to the virtual machines may be sizeable, it is recommended that vizor be setup in this configuration.

     -------------            -------            ----------------------
    |  ISO Server | <======> | vizor | <======> | VM Being Provisioned |
     ------------             -------            ......................

This setup reduces the contention on a single interface.

### Other recommendations

    * Jumbo Frames on the network link to server(s) housing the ISOs.
    * Increase in amount of RAM for caching.

# Getting Started

Refer to the USAGE document.

# BUGS/TODO

The code is alpha quality and numerous issues lie uncovered. Testing, bug fixes welcome.

    * vizor does not clean up artefacts (nodes, repos) created in razor
    * Much work is needed to the powershell provisioner sequence engine.
    * some supporting services (razor, elasticsearch) occasionally fail to start on reboot.
