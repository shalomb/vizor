#!/bin/bash

set -a

     curl_x86_url='http://www.confusedbycode.com/curl/curl-7.38.0-win32.zip'
  curl_x86_64_url='http://www.confusedbycode.com/curl/curl-7.38.0-win64.zip'
         ipxe_url='git://git.ipxe.org/ipxe.git'
kb3aik_en_iso_url='http://download.microsoft.com/download/8/E/9/8E9BBC64-E6F8-457C-9B8D-F6C9A16E6D6A/KB3AIK_EN.iso'
      wimboot_url='https://git.ipxe.org/releases/wimboot/wimboot-2.3.0.tar.bz2'
       wimlib_url='http://sourceforge.net/projects/wimlib/files/wimlib-1.7.2.tar.gz'

overlay_dir='/usr/src/winpe-overlay'
razor_client_script="$PWD/razor-client.cmd"

# Assume RAZOR_SERVER is the current host
RAZOR_SERVER=$( hostname -f )
# Uncomment this line below to get nodes to use IP addresses instead
# RAZOR_SERVER=$(ip addr show dev eth0 | awk -F'[ /]' '/inet .*scope.*global/{print $6}')

RAZOR_DEVELOPMENT_ENV='development'
RAZOR_TEST_ENV='test'
RAZOR_PRODUCTION_ENV='production'

RBENV_ROOT='/usr/src/rbenv'

RAZOR_DB_PASSWORD="${RAZOR_DB_PASSWORD:-$(die "RAZOR_DB_PASSWORD is not set")}"

RAZOR_ROOT='/usr/src/razor-server'
RAZOR_WINPE_CLIENT_SCRIPT="$RAZOR_ROOT/tasks/winpe.task/razor-client.cmd"
