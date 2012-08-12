#!/bin/bash
#
# Copyright 2012 Aron Griffis <aron@arongriffis.com>
# Released under the GNU GPL v3
# Email me to request another license if needed for your project.
#
# TODO:
#  * proper parsing of the getopt cmdline to match GNU getopt synopses
#  * GETOPT_COMPATIBLE
#  * POSIXLY_CORRECT
#  * getopt return codes
#  * support for -a --alternative
#  * support for -q --quiet
#  * support for -Q --quiet-output
#  * support for -s --shell
#  * support for -u --unquoted
#  * support for -T --test (why not?)
#  * full list of differences between this and GNU getopt (should be short)

getopt() {
  _getopt() {
    if [[ "$1 $3 $5 $7" != "-o --long -n --" ]]; then
      echo "Assertion failed: getopt call changed." >&2
      return 1
    fi

    declare short="$2" long="$4" name="$6" opts=() params=() o
    set -- "${@:8}"

    while [[ $# -gt 0 ]]; do
      case $1 in
        (--)
          params+=( "${@:2}" )
          break ;;

        (--*=*)
          o=${1%%=*}
          if [[ ,"$long", == *,"${o#--}":,* ]]; then
            opts+=( "$o" "${o#*=}" )
          elif [[ ,"$long", == *,"${o#--}",* ]]; then
            echo "$name: option '$o' doesn't allow an argument" >&2
            return 1
          else
            echo "$name: unrecognized option '$o'" >&2
            return 1
          fi ;;

        (--?*)
          o=$1
          if [[ ,"$long", == *,"${o#--}",* ]]; then
            opts+=( "$o" )
          elif [[ ,"$long", == *,"${o#--}:",* ]]; then
            if [[ $# -ge 2 ]]; then
              shift
              opts+=( "$o" "$1" )
            else
              echo "$name: option '$o' requires an argument" >&2
              return 1
            fi
          else
            echo "$name: unrecognized option '$o'" >&2
            return 1
          fi ;;

        (-*)
          o=${1::2}
          if [[ "$short" == *"${o#-}":* ]]; then
            if [[ ${#1} -gt 2 ]]; then
              opts+=( "$o" "${1:2}" )
            elif [[ $# -ge 2 ]]; then
              shift
              opts+=( "$o" "$1" )
            else
              echo "$name: option '$o' requires an argument" >&2
            fi
          elif [[ "$short" == *"${o#-}"* ]]; then
            opts+=( "$o" )
            if [[ ${#1} -gt 2 ]]; then
              set -- "$o" "-${1:2}" "${@:2}"
            fi
          else
            echo "$name: unrecognized option '$o'" >&2
            return 1
          fi ;;

        (*)
          params+=( "$1" ) ;;
      esac

      shift
    done

    if [[ ${#opts[@]} -gt 0 ]]; then
      printf '%q ' "${opts[@]}"
    fi
    printf '%s' '--'
    if [[ ${#params[@]} -gt 0 ]]; then
      printf ' %q' "${params[@]}"
    fi
    echo
  }

  _getopt "$@"
}

# vim:sw=2
