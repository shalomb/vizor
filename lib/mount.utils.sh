#!/bin/bash

source apache.sh

function mount_iso {
  local file="$1"
  local dirs=( $(mount-point "$file" -f directory) )

  if [[ ${#dirs[@]-} != 0 ]] ; then
    echo $dirs
    return
  fi

  # Probably need a better way to do this
  if ! losetup -f &>/dev/null; then
    max=0; for i in /dev/loop[0-9]*; do i="${i##*loop}"; (( max = i > max ? i : max )); done 
    next_loop_id=$(( 1 + max ))
    mknod -m660 "/dev/loop$next_loop_id" b 7 "$next_loop_id" >&2
  fi

  mount_point="$file"
  mount_point="${mount_point##[./]}"
  mount_point="${mount_point##mnt/url/}"
  mount_point="${mount_point##url/}"
  mount_point="${mount_point##*/src/}"
  mount_point="$DOCUMENT_ROOT/iso/${mount_point//[!A-Za-z0-9_.-]/_}"

  mkdir -p "$mount_point"
  if mount -o loop,ro,mode=0777,utf8,uid=33,gid=33 "$file" "$mount_point" >&2; then
      echo "$mount_point"
  fi
}

function mount_url {
  local url="$1"
  local type="${url%://*}"
  
  case "$type" in
    cifs)
      local username="${url#*://}"
      local hostname="${username#*@}"
      local username="${username%@*}"
      local password="${username#*:}"
      local username="${username%:*}"
      local path="${hostname#*/}"
      local hostname="${hostname%%/*}"
    ;;
    nfs)
      local url="${url#*://}"
      local hostname="${url%%[:/]*}"
      local path="/${url#*[:/]}"
      ;;
    file)
      local path="${url##*://}"
      ;;
    *)
      die "Unsupported/Unimplemented URI scheme '$type'"
    ;;
  esac

  path="${path//\/.\///}"
  path="${path//\/\///}"

  if [[ ${hostname:-} ]]; then
    mount_point="$DOCUMENT_ROOT/src/${hostname//[!0-9A-Za-z_.]/}/${path//[!0-9A-Za-z\$\/_.,]/}"
  else
    mount_point="$DOCUMENT_ROOT/src/${path//[!0-9A-Za-z\$\/_.,]/}"
  fi
 
  [[ -e $mount_point ]] || mkdir -p "$mount_point" &>/dev/null

  is_mount_point_empty=0;   is_empty "$mount_point"      && is_mount_point_empty=1
  is_mount_point_mounted=0; mountpoint -q "$mount_point" && is_mount_point_mounted=1

  if (( is_mount_point_empty && ! is_mount_point_mounted )); then
    mount_point="${mount_point//\/\///}"
    case "$type" in
      nfs)
        if ! mount -t "$type" -o 'ro,bg,intr,soft,tcp'   "$hostname:$path"   "$mount_point"; then
          die "mounting $hostname:$path to $mount_point failed."
        fi
      ;;
      cifs)
        if ! mount -t "$type" -o 'ro,intr,directio,soft' "//$hostname/$path" "$mount_point" -o "username=${username},password=${password}"; then
          die "mounting //$hostname/$path to $mount_point failed."
        fi
      ;;
      file)
        if ! mount --bind "$path" "$mount_point"; then
          die "mounting $path to $mount_point failed."
        fi
      ;;
      *)
        mount -t "$type" "$hostname:$path" "$mount_point"
      ;;
    esac
  fi

  echo "$mount_point"
}


