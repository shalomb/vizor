#!/bin/bash

source colours.sh

function print_stacktrace() {
  local frame=0

  echo -e "$*"
  ( set +eu
    while caller "$frame"; do
      ((frame++));
    done 2>&1 | sed 's/^/  /'
  )
}

# logger -is -t "$0" "$msg"
function log  {
  echo "${gray}$(date +%FT%T) ${0##${0%/*/*}/}[$$]:${cyan} $@${reset}" >&2 ; 
  logger -i -t "$0" "$@"
}
function warn { print_stacktrace "${red}WARNING : $@${reset}" >&2; return 0; }
function die  { print_stacktrace "${red}ERROR : $@${reset}" >&2; exit 27; }
function log_status { echo -ne "\033[2K\r$@" >&2; }

function assert {
  local boolean="$1"
  local warning="${2:-}"

  (( ! boolean )) && die "$warning" >&2
}

function debug_handler {
  if [[ ${DEBUG-} ]]; then
    cat -
  else
    cat -> /dev/null;
  fi
}

function cmd_exists {
  local cmd="$1"
  type -P "$cmd" &>/dev/null || {
    return 1
  };
  return 0
}

function join { local IFS="$1"; shift; echo "$*"; }

function grep_color {
  local regex="$1"
  local file="$2"

  perl -00 -ne '
    use Term::ANSIColor qw[:constants]; 
    if ( /'"$regex"'/is ) {
      s/('"$regex"')/BRIGHT_GREEN $1, RESET/iegs if -t STDOUT;
      print;
    }
  ' "$file" 
}

function is_empty {
  local dir="$1"
  files=$(shopt -s nullglob dotglob; echo "$dir"/*)
  (( ${#files} == 0 )) && return 0
  return 1
} 

function namesum {
  local name="${1:-$(</dev/stdin)}"
  openssl dgst -sha1 -binary <<<"$name" |
    perl -ne 'use MIME::Base32; undef $/; print MIME::Base32::encode($_)'
}

function join_array {
  local join_str="$1";
  shift;
  printf "%s$join_str" "$@" | sed 's/'"$join_str"'$//';
}

## function curl {
##   command curl --write-out '
##     {
##       "http_code":"%{http_code}",
##       "time_total":"%{time_total}",
##       "content_type":"%{content_type}",
##       "url_effective":"%{url_effective}"
##     }' "$@"
## }

function uuidgen {
  local bytes="${1:-36}"
  head -c "$bytes" < /proc/sys/kernel/random/uuid
}

function patch_yaml {
  local file="$1";  shift;
  local key="$1";   shift;

  cp -a "$file" "$file.$$.$(date +%s)"

  perl -le '
    use strict;
    use warnings;
    use autodie;
    use YAML qw[Load DumpFile];

    my ($file, $key, @values) = (@ARGV);

    my $yaml = do { 
      local $/ = undef;
      open my $fh, "<", $file; 
      my $yaml = Load(<$fh>); 
    };
    my $ptr = \$yaml;
    for my $iter (split m{/}, $key) { 
      $ptr = \$$ptr->{$iter}; 
    }
    $$ptr = scalar @values > 1 ? [ @values ] : $values[0];
    eval { DumpFile($file, $yaml) };
    die "$@" if $@;
  ' "$file" "$key" "$@"

}

export -f patch_yaml

# Documentation Utils
function get_cmd_synopis {
  local file="$1"
  local msg=$( awk 'BEGIN{RS="\n\n"}/SYNOPSIS|synopsis/' "$file" | \
    grep -vi 'synopsis' | sed -r -e 's/^[ \t#]*//' -e 's/\n//g' || true )
  msg="${msg//$'\n'/}"
  echo "$msg"
}

function show_help {
  { cat <<EOF

  ${CMDLINE% -*} - $( get_cmd_synopis "$SCRIPT" )

$( perl -ne ' printf "    -%s    -- %s\n", $1, $2 
        if (/getopt/../esac/ and /(\S+)\).*?\s+([[:alnum:]_+]+?)[=;]/)
      ' "$SCRIPT" )

EOF
  } >&2 
}

