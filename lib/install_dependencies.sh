#!/bin/bash

# SYNOPSIS
#   Invoke caller's dependency script.

distro=$(lsb_release -is | tr 'A-Z' 'a-z')
if [[ -z $distro ]]; then
  grep -Eqi -e 'centos|fedora|redhat' /etc/redhat-release && distro=rhel
fi

case "$distro" in
  debian|ubuntu)
    source "${DIR}/${SCRIPT##*/}.$distro"
  ;;
  centos|rhel)
    source "${DIR}/${SCRIPT##*/}.rhel"
    ;;
  *)
    die "Unsupported distribution '$distro'.";
  ;;
esac


