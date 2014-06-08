#!/bin/bash

     curl_x86_url="http://www.confusedbycode.com/curl/curl-7.37.0-win32.zip"
   curl_amd64_url="http://www.confusedbycode.com/curl/curl-7.37.0-win64.zip"
         ipxe_url='git://git.ipxe.org/ipxe.git'
kb3aik_en_iso_url='http://download.microsoft.com/download/8/E/9/8E9BBC64-E6F8-457C-9B8D-F6C9A16E6D6A/KB3AIK_EN.iso'
      wimboot_url='https://git.ipxe.org/releases/wimboot/wimboot-latest.tar.bz2' # FIXME
       wimlib_url='http://sourceforge.net/projects/wimlib/files/wimlib-1.6.2.tar.gz'

overlay_dir='/usr/src/winpe-overlay'
razor_client_script="$PWD/razor-client.cmd"

# Assume RAZOR_SERVER is the current host
RAZOR_SERVER=$(ip addr | grep -i 'inet ' | grep -i 'scope.*global' | awk -F'[ /]' '{print $6}' | sort -u)
