# Using Vizor

This document walks through the steps to start building windows vms/templates.

# Terms
  * box

    Is an ISO/install image + optional metadata definition (e.g. Win7-x86). It is defined once to be built on one-or-more providers.

  * container

    Is a hypervisor/cloud offering (of RAM, CPU, Networks, Storage, etc).


## Build up the install image catalogs

### NOTE

> The command set here is being revised and therefore not stable as an API.

## Setup Command Autocompletion

    source /usr/src/vizor/lib/completion.sh

## Install ISO Repositories

Atleast one ISO repository is required to be defined in /etc/default/vizor.d/windows_iso_dirs

    echo "iso cifs://username:password@cifsserver.example.com/isos dir1/ dir2/" > /etc/default/vizor.d/windows_iso_dirs
    echo "iso nfs://nfsserver.example.com/isos                     dir1/ dir2/" > /etc/default/vizor.d/windows_iso_dirs
    echo "iso file:///path/to/isos                                 dir1/ dir2/" > /etc/default/vizor.d/windows_iso_dirs

The following commands scan the known ISOs to build up the ISO catalog.

    vizor windows iso update
    vizor iso list

## Discovering available install images (WIM files)

To discover the available install image provided within the available ISOs

    vizor windows image update
    vizor image list

## Discovering available language packs (lp.cab files)

This is only a requirement when building internationalized/localized VMs where
language packs are applied on top of a base locale (e.g. en-US).

    vizor windows langpack update
    vizor windows langpack list


# Preparing vizor for infrastructure access

## Preparing CloudPlatform/CloudStack

Use the [CloudMonkey Getting Started instructions](https://cwiki.apache.org/confluence/display/CLOUDSTACK/CloudStack+cloudmonkey+CLI#CloudStackcloudmonkeyCLI-Gettingstarted)
    to supply the URL and API/Secret keys for the management server.

Additionally, details about the zone are required (later) and so the following may need to be prepared upfront.

  * Service Offerings
  * Disk Offerings
  * Guest Networks
  * Zone Name (If multiple zones exist)
  * Clusters for hypervisor types (e.g. XenServer, ESX, Hyper-V, etc)

## Preparing XenServer

### Copy the razor boot iso and scripts over to the xenserver host

    vizor xenserver -h xshost.example.com -u root -p s3cr3t

### Scan the xenserver host for install template definitions

    vizor xenserver vm-container scan -h xshost.example.com

# Building VMs

## Create the necessary VM containers

VM Containers are the attribute definions of the hypervisor/cloud provider
(Amount of RAM, Numbers of CPUs, Hard Disk Sizes, etc) for the VM used to
build a box.

## CloudStack/CloudPlatform VM containers

    vizor cloudstack vm-container create \
       -n 'zone01-stage-60gbhdd-2vcpu-2gbram-guestnet01' \
       -d '60gb' \
       -s "std.vm 2vcpu 2GB RAM" \
       -z zone01 \
       -N guestnet01 \
       -k us \
       -g imageprep \
       -h XenServer

## XenServer VM containers

This is done by taking one of the XenServer-provided install templates
and override any of the parameters such as RAM, CPU, etc.

e.g. To install a Windows 7 64-bit VM in a container with

* 2 VCPUs
* 2 GiB RAM
* 100 GiB HDD on the Local Storage SR
* Primary Network Interface on the network named 'Public Network'

First select an appropriate container from the cache

    vizor xenserver vm-container list  # Make note of the $id

Create the container for vizor

    vizor container create -t xenserver -n 'my_windows_7_vm_container' \
        -I "Windows_7-x86_64-1_VCPUs-02.00_GiB_RAM-24.00_GiB_HDD" \
        -c 2 \
        -M $((2*1024**3)) \
        -d $((100*1024**3)) \
        -s 'Local storage' \
        -N 'Public Network' \
        -i ipxe.iso

# Building VMs

To build a VM, a box definition is required to map an install image to a VM
container in the infrastructure provider (hypervisor).

A single box definition can then be used to build the same VM on any of the
VM containers known to the system. (i.e. Define once, build anywhere).

### Select an available image

    vizor image list                             # Make note of the ID (i.e. $image_id)

### Create a box for the given image.

    vizor box create -i $image_id                # Make note of the returned Id (i.e. $box_id)

### Build the box in an available container
Set the box to build in a given infrastructure provider (via the container definition).

    vizor box build -b $box_id -c $container_id  # Variables may need to quoted if contents have spaces, etc.

Additionally, razor metadata can be supplied for razor to make use of
when evaluating the .erb templates for the razor task used (winpe.task).

    declare metadata='
      { "administrative_password": "s3cr3t",
        "windows_timezone":        "Eastern Standard time",
        "wsus_url":                "http://wsus.example.com:8530",
        "kms_server":              "kms.example.com",
        "ntp_server_list":         "ntp.example.com",
        "install_dotnet35":        true,
        "l18n_input_locale":       "en-US"
      }
    '
    vizor box build -b $box_id -c $container_id -m "$metadata"

For the most part, vizor will attempt to default most of the metadata to reduce
the amount of metadata needed to be supplied at build time.

To determine which metadata tags to use/override, an inspection of the ruby
templates (.erb) in the razor winpe task is needed.

e.g. to list the metadata keys in unattended.xml.erb

    cd razor/task/winpe.task/
    grep -Ehio 'node.metadata[^]]+\]' *.erb | sort -u

    node.metadata['default_locale']
    node.metadata['input_locale']
    node.metadata['l18n_input_locale']
    node.metadata['l18n_system_locale']
    node.metadata['l18n_user_locale']
    node.metadata['system_locale']
    node.metadata['user_locale']
    ...

Any of the keys listed here can be overridden by extending the JSON metadata
structure to the `vizor box build` command (example shown above).

# Converting VMs to VM Templates

## For CloudStack

This  process works by shortlisting those VMs to be converted and using
`vizor cloudstack template create` over each VM.

    # 20150126 here is part of the VMs' name.
    vizor cloudstack vm list  | awk '/20150126/{print $2" "$4}' |
      while read uuid name; do 
        vizor cloudstack template create -i "$uuid" -n "$name" -f -p;
      done

The parent VMs for the templates are not purged/deleted and must be removed
separately. The `vizor cloudstack template delete` in a similar loop can be
used.

## For XenServer

    vizor xenserver template create -n '20150204'  # Convert VMs with 20150204 in their name
# 
