## Terms used in this guide

  * box

    Is an ISO/install image + optional metadata definition (e.g. Win7-x86, Win10beta-x64, etc) from which VM instances will be built. Boxes are defined once with the view of being provisioned on multiple different cloud or hypervisor providers (via containers).

  * container

    Is a hypervisor/cloud offering (of RAM, CPU, Networks, Storage, etc) to deploy VMs and build boxes in.

  * metadata

    Is the data (runtime parameters used by script templates) that is used to customize the build of one or more boxes.

  * image

    Is an install image (e.g. install.wim, boot.wim, etc) contained with an .iso file. An image is associated with one or more boxes.

  * instance

    In the context of vizor, this is an instance of a box (that defines a XenServer VM or a Cloudstack instance, etc).In the context of CloudStack, this is a virtual machine.

  * template

    Is a virtual machine template in the context of virtual machines instances. In the context of razor, this is a ruby template (.erb).

  * node

    Is a virtual or physical machine that is to be provisioned by razor.

