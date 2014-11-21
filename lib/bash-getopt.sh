# vim: set ts=4 sw=4 tw=0 ft=sh et :
################################################################################
#
# NAME: bash-getopt (aka better-bash-getopt)
#
#  This is (IMO) a better way to do option processing from bash.
#
# USAGE:
#
#  Source this file from any bash script, then process your options like this:
#
#   # assume $foo_dflt is set to some sane default earlier in the script
#   bash-getopt "$@" <<END_OPTS
#
#     FOO=f|foo:NAME "$foo_dflt" "this is a description for the option. it can
#         span multiple lines. foo has a single : so a value is required when
#         the option is used"
#
#     BAR=b|bar::PATH  "" "bar has :: after it, so passing a value is optional"
#
#     ZIP=z|zip "zip has no :, so it is a boolean flag. flag options only need
#         a description; the default is *always* the empty string"
#
#   END_OPTS
#
#  Upon successful processing of the above options, the calling script will
#  have the variables $FOO, $BAR, and $ZIP available. Any positional arguments
#  found will be put into an array, ${ARGV[@]}. The original $@ will be
#  unmodified. In addition, there will be a _usage function available which
#  the caller may use if, for example, they do additional validation of the
#  values in the option variables (say, checking that $BAR is a valid path)
#
#  If there is an error, a well-formatted usage message will be displayed on
#  STDERR and the script will exit. -h and --help options are automatically
#  generated and display help on STDOUT when used.
#
#  The behavior/semantics of the option processing is identical* to GNU getopt,
#  as that is actually what is called to finally do the option processing.
#
#   * identical except for one thing. a when GNU getopt gets the value of a
#     short-opt, like -f, it does something annoying. -f'wibble' and -fwibble
#     do what you expect, but -f="wibble" gets the value "=wibble" which is
#     *not* what I expect. There is code in here to "fix" this, so you do get
#     "wibble" from -f="wibble", even though it's not 100% identical behavior.
#
# COMPATIBILITY:
#
#  This has currently been tested and is known to work on the following
#  OS/Bash/getopt configurations:
#
#    Mac OS X 10.7.5, bash 3.2.48, GNU getopt (enhanced) 1.1.4 (from homebrew)
#    CentOS 6.3,      bash 4.1.2,  GNU getopt (enhanced) 1.1.4
#    CentOS 5.5,      bash 3.2.25, GNU getopt (enhanced) 1.1.4
#
#  It will not work with the BSD-style getopt shipped with Mac OS X. You'll
#  need to install GNU getopt and put it in your path before the system
#  getopt. I doubt it will work with versions of bash prior to 3.x
#
#  Except GNU getopt, no other external programs are used.
#
# DESCRIPTION:
#
#  This is an implementation of an idea I've had kicking around for a while.
#
#  Using named (vs positional) options in shell scripts involves writing way
#  too much boilerplate, repetition of information, and is just an overall
#  PITA.
#
#  Combine that with the limitations of bash's builtin getopts, and the
#  shortcomings of GNU getopt, having to edit multiple places in a script
#  when adding or changing options, and the fact that people regularly take
#  shortcuts and/or make mistakes... you get the idea.
#
#  bash-getopt is designed to be easy to use, relatively intuitive, and
#  to eliminate repeated information and unnecessary boilerplate as much
#  as possible.
#
#  It is still being fleshed out, but the current implementation is reasonably
#  complete, and seems to be quite stable and fast.
#
# OPTION DEFINITIONS
#
#  The lines in the "heredoc" in the example above are called "Option
#  Definitions". An option definition has either two or three fields,
#  depending on the type of option (which is defined in the first field)
#
#  The first field is the "Option Specification" and has a format and syntax
#  described in more detail below. The specification defines, among other
#  things, the "type" of the option - boolean flag, value required, or value
#  optional.
#
#  After the specification field, boolean flag options only have one
#  additional field, a description for including in usage/help output.
#  The two value option types have two more fields, the first being the
#  default value for when the option is not used by the caller of the
#  script, the second being the afore-mentioned description field.
#
#  boolean/flag options do not have a field for setting a default because
#  it's simply not necessary. If the option was used, the value is 1. If
#  the option was not used, the value is the empty string, "". Note that
#  the variable still gets created and set, so you can check it when the
#  nounset shell option is in effect.
#
#  If a default or description field will contain spaces, it must be quoted.
#  Standard shell quoting rules apply. Because of the way the definitions are
#  processed, a description can span multiple lines, but the extra whitespace
#  will get collapsed. Also, there can be blank-lines between option
#  definitions for better readability.
#
#  A previous version of bash-getopt even supported bash-style comments in
#  between the definitions, but the code to do that properly has been deemed
#  more trouble than the feature is worth, for now.
#
# OPTION SPECIFICATIONS
#
#  An "option specification" allows you to succinctly express a lot of
#  information about your program's command-line options. Using one of the
#  examples above, the format for an option specification is parsed like this:
#
#              FOO=f|foo:NAME
#               |  |  | | |
#   var name ---+  |  | | |  required
#   short name ----+  | | |  optional*
#   long name --------+ | |  optional*
#   type indicator -----+ |  can be :,:: or not present
#   value unit -----------+  optional, only valid if type indicator is present
#
#       * you may omit a short name or long name, but never both.
#         if one is omitted, the | separator must also be omitted.
#
#  In this case, the value of this option will be assigned to a variable named
#  $FOO, you can use this option with either -f or --foo, the type indicates
#  that this is a value-required option, and in the help text the value will
#  referred to as NAME.
#
# Var Name:
#
#  The variable name can be composed of any characters that are typically
#  valid for a variable name, [_0-9a-zA-Z]. The variable name is required
#  because making it optional just doesn't seem worth the effort and code.
#
# Short and Long Names:
#
#  The short and long names for the option are separated by a pipe ("|").
#  There can only be one of each type of name for the option but you can omit
#  one or the other if you wish (examples: FOO=f:NAME or FOO=foo:NAME)
#
#  The short name can be any character in [0-9a-zA-Z]. I might be able to
#  allow a single dash as well, but I haven't yet tested it.
#
#  The long name can be composed of any characters that are typically
#  recognized as valid in an option name, [-_0-9a-zA-Z] but it must begin
#  with a letter or number and must not end with a dash ("-")
#
# Type Indicator
#
#  The type indicator can be zero, one, or two colons (":"). The indicator
#  has the same semantics as it does with GNU getopt: A single colon indicates
#  that if the option is used, a value *must* be supplied. Two indicates that
#  if the option is used, a value *may* be supplied. No colons indicate that
#  the option is a boolean flag, and using it results in a value of "1" and
#  not using it results in a value of the empty string ("").
#
# Value Unit:
#
#  The "value unit" is used when showing usage or help text to indicate to the
#  user what the value represents. For example, the usage will show this for
#  foo: "--foo=NAME". The value unit can only be specified when the option
#  type is one that takes a value; It can't be used with boolean/flag options
#  because it makes no sense. (ok, very *little* sense). The value unit is
#  optional. Simply omit it if you do not want one. (example: FOO=f|foo:)
#
# ADDITIONAL NOTES
#
#  If there is an environment var named DEBUG present and it is set to a true
#  value (anything but 0,'', and unset), various bits of debugging info will
#  be displayed. This can come in handy when filing a bug report, or if you
#  just plain like that sort of thing.
#
#
################################################################################

# this file should only ever be sourced.
# But... if it's executed directly, let's try to helpful!
if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
    _show_help () {
        echo -n "SHOWING HELP FOR ${BASH_SOURCE[0]}..."
        sed -nr '/^########/,/^########/{s/^#*//;p}' "${BASH_SOURCE[0]}"
    }

    if [[ -t 1 ]]; then
        # if STDOUT is connected to a terminal, show help using a pager
        _show_help | "${PAGER-less}"
    else
        # if it isn't a terminal, just spew to STDERR
        _show_help >&2
    fi
    exit 1
fi

###
### TODO: see if the utility functions in this script (warn,debug,is-true,etc)
###       can either be used to augment Ed's utils, or be replaced by them.
###

# the stuff below, I'm just thinking about, for now. I'm not certain there
# won't be unexpected difficulties with changing shell opts in sourced code
# and trying to restore them *correctly* before returning to the caller.
# I wonder if something like this could work:
#   manage-settings () {
#     get-settings () { set +o; }
#     local _saved_settings="$(get-settings)"
#     restore-settings () { eval $_saved_settings; }
#     return-handler () { trap - RETURN; restore-settings; }
#     echo trap return-handler RETURN;
#   }
#   # within a function in the sourced script
#   eval manage-settings
#   use-strict () { set -o errexit -o nounset -o pipefail; }
#   # and the return handler would restore the settings (maybe)

# Output the args or piped STDIN to STDERR. For args, behaves just like
# echo, so for example, you can use the -n and -e flags.
warn () {
    if [[ $# -ne 0 ]]; then
        echo >&2 "$@"
    else
        cat >&2
    fi
}

# returns true if all arguments evaluate to true.
# (eg, not 0 or ''). if any arguments are false, returns
# false. if no arguments are supplied, returns false.
# (therefore, this function considers an empty arglist
# to be false)
all-true () {
    local rc=1
    while [[ $# -gt 0 ]]; do
        case "$1" in
            0|'') rc=1; break;;
            *) rc=0; shift;;
        esac
    done
    return $rc
}

# same as all-true, but for a single argument (or no arguments)
is-true () { [[ $# -gt 0 ]] || return 1; all-true "$1"; }

# returns true if all arguments evaluate to false.
# (eg, 0 or ''). if any arguments are true, returns false.
# if no arguments are supplied, returns true (therefore,
# this function considers an empty arglist to be false)
all-false () {
    local rc=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            0|'') shift;;
            *) rc=1; break;;
        esac
    done
    return $rc
}

# same as all-false but for a single argument (or no arguments)
is-false () { [[ $# -gt 0 ]] || return 0; all-false "$1"; }


# equivalient to warn if $DEBUG is true.
debug () {
    is-false "${DEBUG-}" || warn "$@"
}

# returns true if all arguments are integers.
# returns false if any argument is not an integer.
# if no arguments supplied, returns false (because
# nothing is not an integer)
all-int () {
    local rc=1
    while [[ $# -gt 0 ]]; do
        if ! printf '%i' "$1" &>/dev/null; then
            rc=1
            break
        else
            rc=0
        fi
        shift
    done
    return $rc
}

# same as all-int but for a single argument (or no arguments)
is-int () { all-int "$1"; }


# Just like perl's croak, report an error from the caller and exit with
# a code indicating an error. The exit code will be one of the following
# (in order of precedence):
#   - the value of the first argument, if it is an integer.
#   - the return code of the last command, it it was not 0.
#   - 1
# You can pass as many arguments to this as you want and they will
# be output as text to STDERR. You can also pipe in text as well.
# If the first argument is an integer, it will not be printed, but
# will be used as the exit code.
croak () {
    local rc=$?
    [[ $rc -ne 0 ]] || rc=1
    if is-int "$1"; then
        rc="$1"
        shift
    fi
    # NOTE: I should check to see if the $(caller 1) should be quoted.
    # the cat with heredoc is there to fix vim's broken syntax hilighting.
    read line sub file <<< $(caller 1); cat <<FIXVIM >/dev/null
<
FIXVIM
    warn "ERROR [$file:$line]: $@"
    exit $rc
}


# returns true if the first argument matches any of the subsequent arguments
in-list () {
    local want="$1"
    shift;
    for x in "$@"; do
        [[ "$x" != "$want" ]] || return 0
    done
    return 1
}

# this version avoids calling external programs, and also supports multi-line
# option definitions.
# This is the main function that users will use.
#
# The arguments to this function are eventually passed to GNU getopt for
# processing just as you would normally use getopt. However, there's a
# mechanism to pass options to this function that are *not* processed by
# getopt, and instead have other effects. Currently, any of these extra
# options are just spliced into the call to GNU getopt, but this function
# might someday have a few options of its own.
#
# Normally, you would just call bash-getopt like this (just imagine the option
# specs are there): bash-getopt "$@"
#
# But when an error occurs, getopt's error message says "getopt: error ..."
#
# If you want that error to look like it came from your program, you can call
# bash-getopt like this: bash-getopt -n "$0" -- "$@"
#
# Note that the program options are separated from the getopt options by a --.
# This is the same thing getopt itself does, so I think it makes sense here.
#
bash-getopt () {

    ## if there's a -- in the arglist, everything before will be used as
    ## an option for this function or passed-thru as an option for GNU
    ## getopt. Everything after the -- is an option to be processed.

    # collect opts for GNU getopt in this array, initializing it
    # with a single null string to avoid errors under nounset
    local -a go_opts=("")
    if in-list '--' "$@"; then
        for (( x=0; x<$#; x++ )); do
            if [[ "$1" == '--' ]]; then
                shift; break
            fi
            go_opts[$x]="'$1'"
            shift
        done
    fi

    # the remaining options are the ones we want to process
    local -a opts=( "$@" )

    # there currently aren't any options for this function but if there were,
    # we'd find them by processing ${go_opts[@]} here.

    # these vars will collect pieces of info: short option names, long names,
    # case statement clauses, and variable initializations
    local go_short='' go_long='' go_cases='' go_vars=''
    local usage_txt='' help_txt=''

    # newline in a variable is useful
    local nl="
"

    # if nothing's been piped into this command, there's an error
    [[ ! -t 0 ]] || croak "Expected option definitions piped on STDIN"

    # read all input into one string. note that this causes read
    # to exit with code 1, hence the || true.
    read -d '' optdefs || true

    # certain characters need to be escaped for the next step
    optdefs="${optdefs//|/\|}"
    optdefs="${optdefs//=/\=}"

    # set the definitions as positional parameters
    eval set -- $optdefs

    # now process these to build the necessary code for processing the
    # actual program options
    while [[ $# -gt 0 ]]; do

        local raw_spec="$1"; shift
        local opt_spec="$raw_spec"; # this one will be edited along the way

        # extract the var, if any, this opt's value will be assigned to
        local opt_var='' rx_varname='^([_0-9a-zA-Z]+)='
        if [[ "$opt_spec" =~ $rx_varname ]]; then
            opt_var="${BASH_REMATCH[1]}"
            opt_spec="${opt_spec##*=}"
        fi

        # extract the "option type indicator" and "unit", if any. (type
        # indicator determines if the option takes parameters and if a value
        # is required, and unit is shown for help & usage output.
        local opt_type='' opt_unit='' rx_typeunit='([:]+)(.*)$'
        if [[ "$opt_spec" =~ $rx_typeunit ]]; then
            opt_type="${BASH_REMATCH[1]}"
            opt_unit="${BASH_REMATCH[2]}"
            opt_spec="${opt_spec%%:*}"
        fi

        # extract short name, long name, and opt type
        local opt_short='' opt_long=''

        local rx_short='^([0-9a-zA-Z])$' # only short name
        local rx_long='^([0-9a-zA-Z][-_0-9a-zA-Z]*[0-9a-zA-Z])$' # only long name
        local rx_both='^([0-9a-zA-Z])[|]([0-9a-zA-Z][-_0-9a-zA-Z]*[0-9a-zA-Z])?$' # both
        if [[ "$opt_spec" =~ $rx_both ]]; then
            opt_short=${BASH_REMATCH[1]}
            opt_long=${BASH_REMATCH[2]}
        elif [[ "$opt_spec" =~ $rx_long ]]; then
            opt_long=${BASH_REMATCH[1]}
        elif [[ "$opt_spec" =~ $rx_short ]]; then
            opt_short=${BASH_REMATCH[1]}
        else
            croak "Option specification [$raw_spec] is invalid"
        fi

        # determine the default value and description
        local opt_default='' opt_descr=''

        if [[ -n "$opt_type" ]]; then
            opt_default="$1"
            opt_descr="$2"
            shift 2
        else
            opt_descr="$1"
            shift
        fi

# kept this since it's useful for debugging.
debug <<END
  Option definition info:
    raw_spec="$raw_spec"
      opt_var="$opt_var"
      opt_spec="$opt_spec"
        opt_short="$opt_short"
        opt_long="$opt_long"
        opt_type="$opt_type"
      opt_unit="$opt_unit"
    opt_default="$opt_default"
    opt_descr="$opt_descr"

END
        ### done parsing the option definition. now generate pieces of code
        ### for actually processing the caller's options and/or outputting
        ### help and usage


        # short & long opts gor gnu getopt
        go_short+="$opt_short$opt_type"
        go_long+="${go_long:+,}$opt_long$opt_type"

        # declare and initialize the exported vars
        go_vars+="export $opt_var='$opt_default'$nl"

        ### build the case clause
        local opt_case_match="$opt_short" # the match part of the clause
        opt_case_match+="${opt_case_match:+|}$opt_long"

        local opt_case_code="" # the code in the case clause
        if [[ -z "$opt_type" ]]; then
            # boolean flag type
            opt_case_code="export $opt_var=1"
        else
            # value type
            # because of a quirk when using a short-opt like "-f=foo" the
            # value ends up as "=foo". this is "fixed" by the ${1#=} below
            opt_case_code="export $opt_var=\${1#=}; shift"
        fi
        go_cases+="${go_cases:+        }$opt_case_match) $opt_case_code;;$nl"

        ### help/usage text
        local opt_help="${opt_short+-$opt_short}"
        opt_help="${opt_help-  } ${opt_long+--$opt_long}"
        [[ -z "$opt_type" ]] || opt_help+="=${opt_unit-VALUE}"
        opt_help+="$opt_descr"
        [[ -z "$opt_type" ]] || opt_help+=" ['$opt_default']"
        help_txt+="  $opt_help$nl"

    done

    # remove extraneous newlines from generated code
    go_vars="${go_vars%
}"
    go_cases="${go_cases%
}"
    help_txt="${help_txt%
}"

    # add options for help output
    go_short+="h"
    go_long+="${go_long:+,}help"

    ### TODO: build up usage & help text
    help_text+="  -h --helpdisplay this help text"
    help_text="$( column -s '' -t <<< "$help_txt" )"



    ### all the necessary pieces are ready! Assemble the getopt
    ### code and stuff it in $go_code
    read -d '' go_code <<END_GETOPT_CODE || true

$go_vars

_usage () {
    cat <<END_USAGE

  usage: \$0 [options]

$help_text

END_USAGE
}

local gotopts
if ! gotopts=\$(getopt -o '$go_short' -l '$go_long' ${go_opts[@]} -- \"\${opts[@]}\"); then
    rc=\$?
    _usage 1>&2
    exit \$rc
fi
eval set -- "\$gotopts"
while [[ \$# -gt 0 ]]; do
    local opt="\${1##-}"; opt="\${opt##-}"
    shift
    case "\$opt" in
        $go_cases
        h|help) _usage; exit 0;;
        '') break;; # end of options
         *) croak "Unrecognized option: [\$1]";;
    esac
done

# put remaining arguments here. done in two statements like this
# because no other way worked for some reason.
export ARGV=""; [[ \$# -eq 0 ]] || ARGV=( "\$@" )

END_GETOPT_CODE



    debug "$go_code"
    eval "$go_code"
}

true # I just felt like putting this here, no real reason.