# Recommended reading

## ipxe

iPXE affords a way of doing HTTP network installs/bootstraps and as such can be
backed by a policy based decision making engine (i.e. razor) to match nodes
up to a particular install task.

vizor obviates razor's microkernel as a way of discovering nodes
and capabilities and instead embeds the [razor bootstrap script](https://github.com/puppetlabs/puppetlabs-razor/blob/master/templates/bootstrap.ipxe.erb)
into a bootable ipxe iso that VMs are set to boot from.

* [iPXE - open source boot firmware [embed]](http://ipxe.org/embed)
* [iPXE - howto:winpe](http://ipxe.org/howto/winpe)

## razor

razor uses iPXE as a mechanism of doing HTTP-based network installs, however
to accomplish unattended windows installs, the windows setup requires that
installation files be present on a SMB/CIFS network share - both razor
and vizor require samba for this purpose with vizor managing the setup of
the repos using ISOs on a separate network share.

vizor deviates slightly from the way razor performs windows installs
(e.g. in the way repos are setup) nevertheless, the following describe the
processes enough to build up background around the core of vizor's 
operations.

* [PE 3.8 » Razor » Overview — Documentation — Puppet Labs](https://docs.puppetlabs.com/pe/latest/razor_intro.html)
* [PE 3.8 » Razor » Setting Up and Installing Windows on Nodes — Documentation — Puppet Labs](https://docs.puppetlabs.com/pe/latest/razor_windows_install.html)
* [Installing windows · puppetlabs/razor-server Wiki](https://github.com/puppetlabs/razor-server/wiki/Installing-windows)

## ERB Templates
With a run-time templating engine all inputs to the various provisioning tasks
(e.g. Windows Sysprep, Localization) that reflect user requirements can be easily
rendered and managed without code complexity.
Install tasks can be customized to deliver nodes in different configuration 
flavours using metadata that is passed in to the task.
Razor uses the Embedded Ruby ERB templating engine and some knowledge of this
is essential to understanding the various .erb templates vizor uses.

* [An Introduction to ERB Templating](http://www.stuartellis.eu/articles/erb/)
* [ERB Template Syntax, Using Puppet Templates — Documentation — Puppet Labs](http://docs.puppetlabs.com/guides/templating.html#erb-template-syntax)
* [Class: ERB (Ruby 2_2_2)](http://ruby-doc.org/stdlib-2.2.2/libdoc/erb/rdoc/ERB.html)
* [ActionView::Base](http://api.rubyonrails.org/classes/ActionView/Base.html)

# References
* [draft-henry-remote-boot-protocol-00 - Intel Preboot Execution Environment](http://tools.ietf.org/html/draft-henry-remote-boot-protocol-00)
