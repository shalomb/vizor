# Building VMs

This document serves as a how-to to perform automated windows installations on VMs on CloudStack or XenServer and the process of creating templates from VMs afterwards.

> The command set documented in this guide is not fully rationalized and 
> therefore not stable as an API.

## Defining ISO Repositories

Vizor's install image index is built up by scanning through the ISO files
named in the ISO repository locations. These repositories are simply a local
or network directory that contain one or more ISO files and vizor will scan
all subdirectories recursively considering every ISO it encounters before
storing information into the iso index.

Atleast one ISO repository is required to be defined in ``/etc/default/vizor.d/windows_iso_dirs``. Vizor uses NFS, CIFS or local directories/mount-points
URLs naming one or more subdirectories to scan (e.g. the following only 
consider the ``win7`` and ``win8`` subdirectories on the server).

    echo "iso cifs://username:password@cifsserver.example.com/isos win7/ win8/" > /etc/default/vizor.d/windows_iso_dirs
    echo "iso nfs://nfsserver.example.com/isos                     win7/ win8/" > /etc/default/vizor.d/windows_iso_dirs
    echo "iso file:///path/to/isos                                 win7/ win8/" > /etc/default/vizor.d/windows_iso_dirs

The following commands then have vizor scan for ISOs and build up the ISO
index.

    vizor windows iso update  # May take several minutes for large ISO collections
    vizor iso list            # Lists the entries in the iso index

## Discovering available install images (WIM files)

To discover the available install images (``sources\install.wim``, 
``sources\boot.wim``, etc) within each of the known ISOs and build up the image
index.

    vizor windows image update  # May take several minutes for large ISO collections
    vizor image list            # List the entries in the image index

## Discovering available language packs (lp.cab files)

This is not required if VM boxes will be created from fully-localized install
ISOs and is only required when building internationalized/localized VMs where
language packs are applied on top of a base locale (e.g. en-US). Refer to 
[Understanding Language Packs](https://technet.microsoft.com/en-gb/library/cc766472%28v=ws.10%29.aspx)
for more information on fully and partially localized OSes/Language Packs.

Language pack ISOs that do not contain install images will be considered by
these commands but they must reside in an ISO respository named above.

    vizor windows langpack update
    vizor windows langpack list

# Infrastructure setup

The following section outlines the preparation needed to be made to vizor
to have it build up an understanding of the the infrastructure 
(hypervisors and clouds, etc) that will be used to build VMs/VM Templates.

These infrastructure pieces are required to be fully setup and functional
before vizor can proceed.

## Preparations for CloudPlatform/CloudStack

Use the [CloudMonkey Getting Started instructions](https://cwiki.apache.org/confluence/display/CLOUDSTACK/CloudStack+cloudmonkey+CLI#CloudStackcloudmonkeyCLI-Gettingstarted)
to set the URL and API/Secret keys for the management server in 
``~/.cloudmonkey/config``. Also ensure that the ``display`` format is set
to ``json``.

e.g.

    [core]
    profile         = local
    asyncblock      = true
    paramcompletion = true
    history_file    = /root/.cloudmonkey/history
    cache_file      = /root/.cloudmonkey/cache
    log_file        = /root/.cloudmonkey/log

    [ui]
    prompt          = 🐵 >
    color           = false
    display         = json

    [local]
    url             = http://management-server.example.com:8080/client/api
    apikey          = Zp3Wf0REQXYBXYRr9_5s_yhNo9vGk8mC-MLEXKZsQM_7v1eElO9wD7pO4azcb48mZQk-8D4xKoi93bGs9_Zixg
    secretkey       = C4hWSbCFdhlIy2t5-xj0QY7H5XaXHJuSP3T0bhIzhwIOhkYjkgpIUmZqsTNo6R8S-T8yClGu0goKUiYp_MA4Q
    expires         = 600
    timeout         = 3600

To test that vizor is able to communicate with cloudstack using these details,
you could try listing some objects vizor would use.

First test cloudmonkey

    $ cloudmonkey list zones
    {
      "count": 1,
      "zone": [
        {
          "allocationstate": "Enabled",
          "dhcpprovider": "VirtualRouter",
          "id": "b10d5199-5fb1-45ad-90c0-36d35355f345",
          "localstorageenabled": false,
          "name": "Global",
          "networktype": "Basic",
          "securitygroupsenabled": true,
          "tags": [],
          "zonetoken": "e3d2e61c-781e-39ff-835f-0864befac5a9"
        }
      ]
    }

Then test vizor

    # vizor cloudstack zone list
     -------------------------------------- -------- -------------- 
    | id                                   | name   | network type |
     -------------------------------------- -------- -------------- 
    | b10d5199-5fb1-45ad-90c0-36d35355f345 | Global | Basic        |
     -------------------------------------- -------- -------------- 

Additionally, details about the zone are required (later in this document) and
so the following may need to be created or details made available upfront.

  * Service Offerings
      * Name of offering from ``vizor cloudstack serviceoffering list``
  * Disk Offerings
      * Name of offering from ``vizor cloudstack diskoffering list``
  * Guest Networks
      * Name of network from ``vizor cloudstack network list``
  * Zone Name (If multiple zones exist)
      * Name of zone from ``vizor cloudstack zone list``
  * Clusters for hypervisor types (e.g. XenServer, ESX, Hyper-V, etc)
      * Name of hypervisor type from ``vizor cloudstack hypervisor list``

## Preparing a XenServer host or pool access

This copies the generated ipxe.iso boot image (generated in the vizor setup
stage) and helper scripts to Dom0 on the XenServer host.

    vizor xenserver -h xshost.example.com -u root -p s3cr3t

Scan the xenserver host for install template definitions, these are used to
create the XenServer containers later.

    vizor xenserver vm-container scan -h xshost.example.com

# Setting up container definitions

Containers are the VM attribute definions of the hypervisor/cloud provider
(Amounts of RAM, Numbers of CPUs, Hard Disk Sizes, etc) for the VM instances
that a box is built in. e.g. To build Windows 2012 R2 Server VM for minimum
requirements, a container with 2GiB RAM, 20GB Disk Space, etc will suffice.
Equally, to support specialized use-case (e.g Database Servers) may require
a container with 32GiB RAM, 16vCPUs and 2000GB Disk space, etc - however, the
box definition does not change and is reused to build VMs across any suitable
containers.

> As OSes in VMs are sensitive to constraints, it is essential that containers
> are created that meet the minimum requirements of the OS within. This is
> especially important during the OS install phase, even if the limits are
> likely to be changed later for derived VM instances.

Depending on the numbers and requirements of VMs to be built, a number
of different containers need to be created for each hypervisor or cloud that
a box is to be built on. e.g. To provide a standard ``Windows 8.1 32-bit``
box on both ``cloudstack`` and ``xenserver``, two containers are required
(one on cloudstack, one on xenserver) to provide VMs to house the box.
While the VMs for the boxes are disparate instances and share no common
lineage (i.e. are not clones or are converted images of the same parent)
- they will be setup by vizor to hold identical configuration and so to
apps and services running within these instances there is (ideally) no
difference.

## CloudStack/CloudPlatform instance containers

Cloudstack containers take on details of the cloudstack cloud,
service offerings, networks, etc that will be used to house the box.

E.g. The following creates a CS container in a zone named 'zone01' with
the service offerings and hypervisor types of that zone.

    vizor container create -t cloudstack \
       -n 'zone01-stage-60gbhdd-2vcpu-2gbram-guestnet01' \
       -d '60gb'                 \
       -s 'std.vm 2vcpu 2GB RAM' \
       -z zone01                 \
       -N guestnet01             \
       -k us                     \
       -g imageprep              \
       -h XenServer

Refer to the help in ``vizor container create -t cloudstack -h`` for
additional arguments.

Various helper commands are provided in vizor to discover details about
cloudstack service/disk offerings, networks, etc. Refer to the help for
the sub-commands under ``vizor cloudstack``.

## XenServer VM containers

XenServer containers take on details of the XenServer host/pool
and the install templates used to build a box in.

This is done by taking one of the XenServer-provided install templates
and overridding any of the parameters such as RAM, CPU, etc.

e.g. To install a Windows 7 64-bit VM in a new container

First select an appropriate container from the cache

    vizor xenserver vm-container list  # Make note of the $id
                                       # e.g. Windows_7-x86_64-1_VCPUs-02.00_GiB_RAM-24.00_GiB_HDD

Create a xenserver container for vizor overridding any of the values.

    vizor container create -t xenserver -n 'my_windows_7_vm_container' \
        -I "$id"             \
        -c 2                 \
        -M $((2*1024**3))    \
        -d $((100*1024**3))  \
        -s 'Local storage'   \
        -N 'Public Network'  \
        -i ipxe.iso

Refer to the help in ``vizor container create -t xenserver -h`` for
additional arguments.

> Xenserver provides install templates that are recommendations
> for the parameters a VM should take and so containers are required to be
> created for every OS type that VMs will be built against. i.e. a
> ``Windows 7 (32-bit)`` install template is only recommended for the
> ``Windows 7`` family and cannot be used for the ``Windows Server 2012 R2``
> family.

# Defining Boxes

To build a VM, a box definition is required to map an install image to a VM
container in the infrastructure provider (hypervisor).

A single box definition can then be used to build the same VM on any of the
VM containers known to the system.

### Select the candidate install image

    vizor image list                             # Make note of the required image's ID (i.e. $image_id)

### Create a box for the given image.

    vizor box create -i $image_id                # Make note of the returned Id (i.e. $box_id)

### Build the box in an available container
Set the box to build in a given infrastructure provider (via the container definition).

    vizor box build -b $box_id -c $container_id  # Variables may need to quoted if contents have spaces, etc.

Additionally and optionally, razor metadata can be supplied for razor to
make use of when evaluating the .erb templates for the razor task used
(``winpe.task``).

This is an example of minimal metadata that customizes the box
(see section below on how to specify other metadata).

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

### Identifying metadata keys

To determine which metadata tags to use/override, an inspection of the ruby
templates (.erb) in the razor winpe task is needed.

e.g. to list the metadata keys in all the .erb files

    root@vizor# cd razor/task/winpe.task/
    root@vizor# grep -Ehio 'node.metadata[^]]+\]' *.erb | sort -u

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

# Batch operations

Batch operations allow for multiple boxes to be built at once
e.g. for a new set of VM templates for a periodic refresh or
to build all VM templates of a particular hypervisor/cloud type.

## Create ``~/.vizor.json``

``~/.vizor.json`` contains the box-container maps and associated metadata for
batch operations to consume.

No tools currently exist to create this file and so must be modelled using the
example template ``batch/vizor.json`` from the source tree with appropriate
edits made.

    cp /usr/src/vizor/batch/vizor.json ~/.vizor.json
    $EDITOR ~/.vizor.json                  # Make edits as appropriate (see the format section below)
    jq -S '.' ~/.vizor.json                # To validate the JSON syntax of the file.

## Format of ``vizor.json``

``vizor.json`` is used to contain definitions of boxes, the various
containers they can be built in and locales that can be iterated
through for every box.

The metadata section contains the metadata key-value pairs that are
substituted in the razor (.erb) templates when processes running in 
the box being prepared request these via the razor web api.

For a list of the keys that can be overridden refer to the 
``Identifying metadata keys`` section above.

The follow minimal example shows how two box-container-locale definitions
are represented with a minimal metadata section.

    {
      "metadata" : {
        "administrative_password": "p455w0rd",
        "windows_timezone":        "Eastern Standard Time",
        "wsus_url":                "http://wsus2.example.com:8530",
        "kms_server":              "kms.example.com",
        "ntp_server_list":         "ntp.example.com",
        "install_dotnet35":        true,
        "install_windows_update":  true,
        "l18n_input_locale":       "en-US"
      },
      "boxes" : {
        "win7_ent-x86-sp1-us-7601": {
          "container": {
            "cloudstack-stage": "stage-xenserver-vlan384-4vCPU-4GB-Large_disk",
            "cloudstack-prod":  "production-xenserver-vlan348-4vCPU-4GB-Large_disk",
            "xenserver-6.2":    "Windows_7-x86-2_VCPUs-2.00_GiB_RAM-100.00_GiB_HDD-Public",
            "xenserver-6.5":    "Windows_7-x86-2_VCPUs-2.00_GiB_RAM-100.00_GiB_HDD-Public"
          },
          "locales": [ "en-US", "fr-FR", "de-DE", "es-ES", "ru-RU",
                       "ja-JP", "ko-KR", "zh-CN", "zh-HK", "th-TH" ]
        },
        "win7_ent-x64-sp1-us-7601": {
          "container": {
            "cloudstack-stage": "stage-xenserver-vlan384-4vCPU-4GB-Large_disk",
            "cloudstack-prod":  "production-xenserver-vlan348-4vCPU-4GB-Large_disk",
            "xenserver-6.2":    "Windows_7-x86_64-2_VCPUs-2.00_GiB_RAM-100.00_GiB_HDD-Public",
            "xenserver-6.5":    "Windows_7-x86_64-2_VCPUs-2.00_GiB_RAM-100.00_GiB_HDD-Public"
          },
          "locales": [ "en-US", "fr-FR", "de-DE", "es-ES", "ru-RU",
                       "ja-JP", "ko-KR", "zh-CN", "zh-HK", "th-TH" ]
        }
    }

The boxes section requires extending for all the boxes that are candidates for
batch operations.

> No schema exists to validate ``~/.vizor.json`` and so must be crafted with due care.

## Examples of batch builds

These commands use ``~/.vizor.json`` and so require it to be present and populated.

    vizor batch build -l 'en' -t cloudstack-stage -n  # build all english boxes on the cloudstack-stage containers

    vizor batch build -b 'win8|w2k12r2' -l 'th|kr' -t xenserver-6.5 -n  # build Windows 8.1/2012 R2 boxes for thai/korean on xenserver-6.5

    vizor batch build -n                              # build all known boxes across all containers and all locales

# Known issues and mitigations

    Error 431: Can't specify network Ids in Basic Zone

    Cloudstak does not support specifying network in the basic zone
    configuration model.
    Workaround: Do not specify the network when creating the container.
