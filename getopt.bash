#!/bin/bash
#
# Copyright 2012 Aron Griffis <aron@arongriffis.com>
# Released under the GNU GPL v3
# Email me to request another license if needed for your project.
#
# DONE:
#  * abbreviated long options
#  * getopt return codes
#  * support for -q --quiet
#  * support for -Q --quiet-output
#  * support for -T --test
#  * support for -u --unquoted
#  * POSIXLY_CORRECT
#  * leading + or - on options string
#
# TODO:
#  * first and second calling form in the synopsis
#  * GETOPT_COMPATIBLE
#  * support for -a --alternative
#  * support for -s --shell
#  * full list of differences between this and GNU getopt
#      * GNU getopt mishandles ambiguities:
#          $ getopt -o '' --long xy,xz -- --x
#           --xy --

getopt() {
  _getopt() {
    declare parsed status
    declare short long name flags

    # Synopsis from getopt man-page:
    #
    #   getopt optstring parameters
    #   getopt [options] [--] optstring parameters
    #   getopt [options] -o|--options optstring [options] [--] parameters
    #
    # Note that although the last synopsis shows the double-dash as
    # optional, it's only optional if there's a non-option parameter at the
    # start of the parameter list.

    parsed=$(_getopt_parse getopt ahl:n:o:qQs:TuV \
      alternative,help,longoptions:,name,options:,quiet,quiet-output,shell:,test,version \
      p "$@")
    status=$?
    eval "set -- $parsed"

    if [[ $status != 0 ]]; then
      echo "Try \`getopt --help' for more information." >&2

      # Errors in first parse always return status 2
      return 2
    fi

    while [[ $# -gt 0 ]]; do
      case $1 in
        (-a|--alternative)
          echo "Sorry, --alternative isn't supported by pure-getopt." >&2
          return 2 ;;

        (-h|--help)
          echo "Sorry, --help isn't supported by pure-getopt." >&2
          return 2 ;;

        (-l|--longoptions)
          long+="${long:+,}$2"
          shift ;;

        (-n|--name)
          name=$2
          shift ;;

        (-o|--options)
          short=$2
          shift ;;

        (-q|--quiet)
          flags+=q ;;

        (-Q|--quiet-output)
          flags+=Q ;;

        (-s|--shell)
          echo "Sorry, --shell isn't supported yet by pure-getopt." >&2
          return 2 ;;

        (-u|--unquoted)
          flags+=u ;;

        (-T|--test)
          return 4 ;;  # TODO: GETOPT_COMPATIBLE

        (-V|--version)
          echo "pure-getopt 0.1"
          return 0 ;;

        (--)
          shift
          break ;;
      esac

      shift
    done

    if [[ $short == -* ]]; then
      flags+=i
      short=${short#?}
    elif [[ $short == +* ]]; then
      flags+=p
      short=${short#?}
    fi
    flags+=${POSIXLY_CORRECT+p}

    _getopt_parse "$name" "$short" "$long" "$flags" "$@"
  }

  _getopt_parse() {
    # Inner getopt parser, used for both getopt parse and program parse.
    declare name="$1" short="$2" long="$3" flags="$4"
    shift 4

    # Split $long on commas, prepend double-dashes, strip colons;
    # for use with _getopt_resolve_abbrev
    declare -a longarr
    _getopt_split longarr "$long"
    longarr=( "${longarr[@]/#/--}" )
    longarr=( "${longarr[@]%:}" )
    longarr=( "${longarr[@]%:}" )

    # Parse and collect options and parameters
    declare -a opts params
    declare o error=0

    while [[ $# -gt 0 ]]; do
      case $1 in
        (--)
          params+=( "${@:2}" )
          break ;;

        (--*=*)
          o=${1%%=*}
          if ! o=$(_getopt_resolve_abbrev "$o" "${longarr[@]}"); then
            error=1
          elif [[ ,"$long", == *,"${o#--}"::,* ]]; then
            opts+=( "$o" "${o#*=}" )
          elif [[ ,"$long", == *,"${o#--}":,* ]]; then
            opts+=( "$o" "${o#*=}" )
          elif [[ ,"$long", == *,"${o#--}",* ]]; then
            _getopt_err "$name: option '$o' doesn't allow an argument"
            error=1
          else
            echo "getopt: assertion failed (1)" >&2
            error=1
          fi ;;

        (--?*)
          o=$1
          if ! o=$(_getopt_resolve_abbrev "$o" "${longarr[@]}"); then
            error=1
          elif [[ ,"$long", == *,"${o#--}",* ]]; then
            opts+=( "$o" )
          elif [[ ,"$long", == *,"${o#--}::",* ]]; then
            opts+=( "$o" '' )
          elif [[ ,"$long", == *,"${o#--}:",* ]]; then
            if [[ $# -ge 2 ]]; then
              shift
              opts+=( "$o" "$1" )
            else
              _getopt_err "$name: option '$o' requires an argument"
              error=1
            fi
          else
            echo "getopt: assertion failed (2)" >&2
            error=1
          fi ;;

        (-*)
          o=${1::2}
          if [[ "$short" == *"${o#-}"::* ]]; then
            if [[ ${#1} -gt 2 ]]; then
              opts+=( "$o" "${1:2}" )
            else
              opts+=( "$o" '' )
            fi
          elif [[ "$short" == *"${o#-}":* ]]; then
            if [[ ${#1} -gt 2 ]]; then
              opts+=( "$o" "${1:2}" )
            elif [[ $# -ge 2 ]]; then
              shift
              opts+=( "$o" "$1" )
            else
              _getopt_err "$name: option '$o' requires an argument"
              error=1
            fi
          elif [[ "$short" == *"${o#-}"* ]]; then
            opts+=( "$o" )
            if [[ ${#1} -gt 2 ]]; then
              set -- "-${1:2}" "${@:2}"
            fi
          else
            _getopt_err "$name: unrecognized option '$o'"
            error=1
          fi ;;

        (*)
          # GNU getopt in-place mode (leading dash on short options)
          # overrides POSIXLY_CORRECT
          if [[ $flags == *i* ]]; then
            opts+=( "$1" )
          elif [[ $flags == *p* ]]; then
            params+=( "$@" )
            break
          else
            params+=( "$1" )
          fi
      esac

      shift
    done

    if [[ $flags == *Q* ]]; then
      true  # generate no output
    elif [[ $flags == *u* ]]; then
      printf '%s -- %s\n' "${opts[*]}" "${params[*]}"
    else
      if [[ ${#opts[@]} -gt 0 ]]; then
        printf '%q ' "${opts[@]}"
      fi
      printf '%s' '--'
      if [[ ${#params[@]} -gt 0 ]]; then
        printf ' %q' "${params[@]}"
      fi
      echo
    fi

    return $error
  }

  _getopt_err() {
    if [[ $flags != *q* ]]; then
      printf '%s\n' "$1" >&2
    fi
  }

  _getopt_resolve_abbrev() {
    # Resolves an abbrevation from a list of possibilities.
    # If the abbreviation is unambiguous, echoes the expansion on stdout
    # and returns 0.  If the abbreviation is ambiguous, prints a message on
    # stderr and returns 1. (For getopt parse this should convert to exit
    # status 2.)  If there is no match at all, prints a message on stderr
    # and returns 2.
    declare a q="$1"
    declare -a matches
    shift
    for a; do
      [[ "$a" == "$q" ]] && { matches=( "$a" ); break; }
      [[ "$a" == "$q"* ]] && matches+=( "$a" )
    done
    case ${#matches[@]} in
      (0)
        printf "$name: unrecognized option %s\n" >&2 \
          "$(_getopt_quote "$q")"
        return 2 ;;
      (1)
        echo "$matches"; return 0 ;;
      (*) 
        printf "$name: option %s is ambiguous; possibilities: %s\n" >&2 \
          "$(_getopt_quote "$q")" "$(_getopt_quote "${matches[@]}")"
        return 1 ;;
    esac
  }

  _getopt_split() {
    # Splits $2 at commas to build array specified by $1
    declare IFS=,
    eval "$1=( \$2 )"
  }

  _getopt_quote() {
    # Quotes arguments with single quotes, escaping inner single quotes
    # appropriately.
    declare i q=\'
    for ((i=1; i<=$#; i++)); do
      (( i > 1 )) && echo -n ' '
      printf "'%s'" "${!i//$q/$q\\$q$q}"
    done
  }

  _getopt "$@"
  declare status=$?
  unset -f _getopt _getopt_parse _getopt_quote _getopt_resolve_abbrev _getopt_split
  return $status
}

# vim:sw=2
