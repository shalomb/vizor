#!/bin/bash

shopt -s sourcepath

_vizor=$(type -P vizor)
if [[ -z $_vizor ]]; then
  if [[ -e ${BASH_SOURCE[0]%/*}/../vizor ]]; then
    _vizor="${BASH_SOURCE[0]%/*}/../vizor"
  fi
fi

if [[ -z $_vizor ]]; then
  echo "vizor not found/installed?" >&2
  return
fi

_vizor_d=$(cd "${_vizor%/*}" && pwd )

PATH="$_vizor_d:$_vizor_d/lib:$PATH"

source "$_vizor_d/lib/utils.sh"

function _vizor {
  local cw="${COMP_WORDS[COMP_CWORD]}"
  
  cp=
  if (( ${#COMP_WORDS[@]} >= 2 )); then
    _IFS="$IFS"; IFS="/"; cp="$_vizor_d/${COMP_WORDS[*]:1}"
    IFS="$_IFS"
  else
    cp="$_vizor_d/"
  fi

  # if [[ $cw ]]; then
  #   cp="$cp$cw"
  #   echo -ne "pending =>$cp ] \n "
  # fi

  [[ -d $cp ]] && cp="$cp/"

  for file in "$cp"*; do
    local f="${file##*/}"
    # echo  -e "[AYE : $cp => $file -> $f]"
    case "$f" in
      *'*') 
        return
        ;;
      *) 
        COMPREPLY+=( "$f" )
        ;;
    esac
  done

}

complete -F _vizor vizor
