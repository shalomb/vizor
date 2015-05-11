# Creating VM Templates from instances

Once box instances are installed and prepared, it may be necessary to create
templates of these for reuse.

## CloudStack Templates

This works by pattern matching (on the instance name) those instances that
require templates to be created from.

More than one instance can be considered to create templates from, e.g.
the following command creates templates for multiple instances that match
somewhere in the VM name

    # 201505 here is part of the VMs' name label
    vizor cloudstack template create -f -p -r 201505

> The parent instances that the templates are created from are not deleted in
> after this command returns and therefore they must be removed separately if
> needed. The `vizor cloudstack vm delete` command can be used for that purpose.

## XenServer Templates

A pattern is supplied to the ``vizor xenserver template create`` command to 
match *all* those VMs that will be converted to instant templates.

The following command converts all VMs to templates matching a particular
pattern somewhere in the VM name-label.

    vizor xenserver template create -n '20150204'

> The parent VMs that templates are created from are not left behing i.e.
> The ``is-a-template=true`` is set for affected VMs.

## Exporting XenServer Templates to a network share

XenServer templates can be exported to a network share for distribution and
vizor provides some facility for exporting either .XVA or .VHD files.

> To speed up exports, xenserver VM/Template exports are done by ``xe(1)``
> commands that are invoked directly from Dom0 on the pool master.
> To that effect mount-points below are created on the pool-master and not on
> the vizor host.

### Exporting templates as .xva

    export HOST='myxspool.example.com'

    vizor xenserver mount \
      -u 'nfs://nfserver.example.com/export' \
      -m '/mnt/xvaexports'

    vizor xenserver template export xva \
      -m '/mnt/xvaexports' \
      -n '20150505'

### Exporting .vhd files

    export HOST='myxspool.example.com'

    vizor xenserver mount \
      -u 'nfs://nfserver.example.com/export' \
      -m '/mnt/xvaexports'

    vizor xenserver template export vhd \
      -m '/mnt/xvaexports' \
      -n '20150505' -m

