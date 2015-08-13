# About vizor

vizor is a tool to perform unattended OS installs for VM and VM template 
preparation activities.

## Objectives

vizor sets out to accomplish these (amongst other) objectives

* Address the need to build VM (and possibly physical) templates against a
  specification in code and avoid the overhead/problems of manual OS
  installations and associated post-install preparations.

* Manage the localization and custom needs of users in various geographical 
  regions (geographic locations, timezones, system and input locales, licensing)
  and provide VMs templates for suitable user-experience.

* Build VM templates with the aim of distribute VM templates for various hypervizor and cloud providers
  (e.g. XenServer, CloudPlatform, Hyper-v Generation 1 & 2, VMWare ESX and possibly others) from few authoritative definitions of the VM deliverables (i.e. the VMs built on XenServer should exactly mirror those built on CloudStack for e.g. while only the platform provider changes).
* Reuse vanilla ISOs to avoid the overhead/problems of remastering them to facilitate automated installs. This is an important consideration when having to build a large number of VMs, periodically and across various geographical sites for different requirements.
* Address the need to perform consistent methods of installation across various virtual and physical machine providers in a standard, platform agnostic manner (by performing network-based unattended OS installations using standard PXE/iPXE).
* Provide an API surface that allows integrations with build systems, orchestration platforms, etc to trigger the build of VM template sets.
* Provide assistive automation to users to build templates to differing requirements or specifications.

## Implementation
vizor builds on top of the PuppetLabs [Razor](https://puppetlabs.com/solutions/next-generation-provisioning) provisioner
([github.com/puppetlabs/razor-server](https://github.com/puppetlabs/razor-server))
by implementing a series of commands in a scripting layer that interface with

* Hypervizor/Cloud providers (currently XenServer and CloudStack) to create and manage virtual machines and associated lifecycles.
* The razor web service to manage node-VM relationships, install repos, tasks, tags and policies to drive unattended installs within nodes.
* ISO and install image catalogs (currently windows ISOs) to manage razor repos.

The commands are implemented as a series of (mainly bash but extensible in any language)
scripts intending to provide a VM/VM template build, provisioning and distribution workflow.

## Components
vizor's component stack is the assembly of following technologies on the Debian platform.

* [razor-server](https://github.com/puppetlabs/razor-server) - REST webservice to provide policy based baremetal provisioning.
* [razor-client](https://github.com/puppetlabs/razor-client) - REST client to the razor-server.
* [samba3](https://github.com/puppetlabs/razor-server/wiki/Installing-windows) - File server to host razor repos of ISO files (razor-server requirement)
* [Apache CouchDB](http://couchdb.apache.org/) - REST-based document (Schema Free, JSON based) database for the data-layer.
* [elasticsearch](https://www.elastic.co/products/elasticsearch) - REST api to use query-based search of data in the data-layer.
* [apache2 httpd](http://httpd.apache.org/) - Web service to host files via HTTP to nodes being provisioned.
* [curl](http://curl.haxx.se/)  - HTTP/HTTPS webclient/CLI to interface with the data-layer.
* [jq](http://stedolan.github.io/jq/) - JSON processor/generator/validator for data in the data-layer (using curl/HTTP as the transport).
* [cloudmonkey](https://pypi.python.org/pypi/cloudmonkey/) - REST client/CLI for the CloudStack web API.
* [xe](http://wiki.xen.org/wiki/XAPI_Command_Line_Interface) - XML-RPC client/CLI for XenServer XAPI (remotely via SSH/PKI)
* Various other standard tools like bash, awk, sed, perl, ruby in scripts.


