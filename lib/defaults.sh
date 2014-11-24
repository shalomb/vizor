#!/bin/bash

shopt -s expand_aliases extglob nullglob sourcepath

set -o errexit # -e
set -o nounset # -u

if [[ ${DEBUG:-} ]]; then
  (( DEBUG > 1 )) && set -o xtrace
  (( DEBUG > 2 )) && set -o verbose
fi

FORCE="${FORCE:-}"

CMD="${0##*/}"
ARGS=( "$@" )

if [[ -z ${CMDLINE-} ]] ; then
  export CMDLINE="$CMD ${ARGS[@]-}"
fi

DIR=$( cd "${BASH_SOURCE[1]%/*}" && pwd )
SCRIPT="$DIR/${BASH_SOURCE[1]##*/}"

PATH="$PATH:$DIR"

PAGER="${PAGER:-less}"

RFC_3339_DATE=$(date --rfc-3339=ns | tr ' ' 'T')
DATE=${RFC_3339_DATE%T*}
TIME=${RFC_3339_DATE#*T}
TIME=${TIME%.*}

TIMEFORMAT='Real: %3lR  User: %3lU  Sys: %3lS  CPU: %P'

