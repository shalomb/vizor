#!/bin/bash

httpd_confs=()
for f in /etc/apache2/sites-enabled/* /etc/httpd.conf*; do
  [[ -e $f ]] && httpd_confs+=( "$f" ) && break
done

if (( ${#httpd_confs[@]} == 0 )); then
  die "No httpd.conf files found. Is apache/httpd installed?"
fi

[[ -z ${DOCUMENT_ROOT-} ]]  && DOCUMENT_ROOT=$( awk '/DocumentRoot/{print $2}' "${httpd_confs[@]}" )
[[ -z ${FQDN-} ]]           && FQDN=$( hostname -f )

function file_url {
  local path="$1"
  local subpath="${path##$DOCUMENT_ROOT}"
  if [[ $path = $subpath ]]; then
    die "$path does not appear to be an item under $DOCUMENT_ROOT"
  fi
  subpath="${subpath#/}"
  echo "http://$FQDN/$subpath"
}

function url_file {
  local url="$1"
  local path="${url##http://$FQDN}"
  if [[ $path = 'http:'* ]]; then
    die "$path does not appear to be a local url"
  fi
  path="$DOCUMENT_ROOT/$path"
  path="${path//\/\///}"
  echo "$path"
}
