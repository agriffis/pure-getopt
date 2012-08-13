#!/bin/bash

getopt() {
  # pure-getopt, a drop-in replacement for GNU getopt in pure Bash.
  # version 1.0
  #
  # Copyright 2012 Aron Griffis <aron@arongriffis.com>
  # Released under the GNU GPL v3
  # Email me to request another license if needed for your project.

  _getopt_main() {
    declare parsed status
    declare short long name flags
    declare have_short=false

    # Synopsis from getopt man-page:
    #
    #   getopt optstring parameters
    #   getopt [options] [--] optstring parameters
    #   getopt [options] -o|--options optstring [options] [--] parameters
    #
    # The first form can be normalized to the third form which
    # _getopt_parse() understands. The second form can be recognized after
    # first parse when $short hasn't been set.

    if [[ $1 == [^-]* ]]; then
      # Normalize first to third synopsis form
      flags+=c
      set -- -o "$1" -- "${@:2}"
    fi

    # First parse always uses flags=p since getopt always parses its own
    # arguments effectively in this mode.
    parsed=$(_getopt_parse getopt ahl:n:o:qQs:TuV \
      alternative,help,longoptions:,name,options:,quiet,quiet-output,shell:,test,version \
      p "$@")
    status=$?
    eval "set -- $parsed"

    if [[ $status != 0 ]]; then
      if [[ $status == 1 ]]; then
        echo "Try \`getopt --help' for more information." >&2
        # Errors in first parse always return status 2
        status=2
      fi
      return $status
    fi

    while [[ $# -gt 0 ]]; do
      case $1 in
        (-a|--alternative)
          flags+=a ;;

        (-h|--help)
          _getopt_help
          return 2  # as does GNU getopt
          ;; 

        (-l|--longoptions)
          long+="${long:+,}$2"
          shift ;;

        (-n|--name)
          name=$2
          shift ;;

        (-o|--options)
          short=$2
          have_short=true
          shift ;;

        (-q|--quiet)
          flags+=q ;;

        (-Q|--quiet-output)
          flags+=Q ;;

        (-s|--shell)
          case $2 in
            (sh|bash)
              flags=${flags//t/} ;;
            (csh|tcsh)
              flags+=t ;;
            (*)
              echo 'getopt: unknown shell after -s or --shell argument' >&2
              echo "Try \`getopt --help' for more information." >&2
              return 2 ;;
          esac

        (-u|--unquoted)
          flags+=u ;;

        (-T|--test)
          return 4 ;;  # TODO: GETOPT_COMPATIBLE

        (-V|--version)
          echo "pure-getopt 1.0"
          return 0 ;;

        (--)
          shift
          break ;;
      esac

      shift
    done

    if ! $have_short; then
      # $short was declared but never set, not even to an empty string.
      # This implies the second form in the synopsis.
      if [[ $# == 0 ]]; then
        echo 'getopt: missing optstring argument' >&2
        echo "Try \`getopt --help' for more information." >&2
        return 2
      fi
      short=$1
      have_short=true
      shift
    fi

    if [[ $short == -* ]]; then
      [[ $flags == *c* ]] || flags+=i
      short=${short#?}
    elif [[ $short == +* ]]; then
      [[ $flags == *c* ]] || flags+=p
      short=${short#?}
    fi
    flags+=${POSIXLY_CORRECT+p}
    flags+=${GETOPT_COMPATIBLE+c}

    _getopt_parse "${name:-getopt}" "$short" "$long" "$flags" "$@" || \
      return 1
  }

  _getopt_parse() {
    # Inner getopt parser, used for both first parse and second parse.
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
    declare o alt_recycled=false error=0

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
            opts+=( "$o" "${1#*=}" )
          elif [[ ,"$long", == *,"${o#--}":,* ]]; then
            opts+=( "$o" "${1#*=}" )
          elif [[ ,"$long", == *,"${o#--}",* ]]; then
            if $alt_recycled; then
              # GNU getopt isn't self-consistent about whether it reports
              # errors with a single dash or double dash in alternative
              # mode, but in this case it reports with a single dash.
              _getopt_err "$name: option '${o#-}' doesn't allow an argument"
            else
              _getopt_err "$name: option '$o' doesn't allow an argument"
            fi
            error=1
          else
            echo "getopt: assertion failed (1)" >&2
            return 3
          fi
          alt_recycled=false
          ;;

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
            return 3
          fi
          alt_recycled=false
          ;;

        (-*)
          if [[ $flags == *a* ]]; then
            # Alternative parsing mode!
            # Try to handle as a long option if any of the following apply:
            #  1. There's an equals sign in the mix -x=3 or -xy=3
            #  2. There's 2+ letters and an abbreviated long match -xy
            #  3. There's a single letter and an exact long match
            #  4. There's a single letter and no short match
            o=${1::2} # temp for testing #4
            if [[ $1 == *=* || $1 == -?? || \
                  ,$long, == *,"${1#-}"[:,]* || \
                  ,$short, != *,"${o#-}"[:,]* ]]; then
              o=$(_getopt_resolve_abbrev "${1%%=*}" "${longarr[@]}" 2>/dev/null)
              case $? in
                (0)
                  # Unambiguous match. Let the long options parser handle
                  # it, with a flag to get the right error message.
                  set -- "-$@"
                  alt_recycled=true
                  continue ;;
                (1)
                  # Ambiguous match, generate error and continue.
                  _getopt_resolve_abbrev "${1%%=*}" "${longarr[@]}" >/dev/null
                  error=1
                  shift
                  continue ;;
                (2)
                  # No match, fall through to single-character check.
                  true ;;
                (*)
                  echo "getopt: assertion failed (3)" >&2
                  return 3 ;;
              esac
            fi
          fi

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
              _getopt_err "$name: option requires an argument -- '${o#-}'"
              error=1
            fi
          elif [[ "$short" == *"${o#-}"* ]]; then
            opts+=( "$o" )
            if [[ ${#1} -gt 2 ]]; then
              set -- "$o" "-${1:2}" "${@:2}"
            fi
          else
            if [[ $flags == *a* ]]; then
              # Alternative parsing mode! Report on the entire failed
              # option. GNU includes =value but we omit it for sanity with
              # very long values.
              _getopt_err "$name: unrecognized option '${1%%=*}'"
            else
              _getopt_err "$name: invalid option -- '${o#-}'"
              if [[ ${#1} -gt 2 ]]; then
                set -- "$o" "-${1:2}" "${@:2}"
              fi
            fi
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
    else
      echo -n ' '
      if [[ $flags == *[cu]* ]]; then
        printf '%s -- %s' "${opts[*]}" "${params[*]}"
      else
        if [[ $flags == *t* ]]; then
          _getopt_quote_csh "${opts[@]}" -- "${params[@]}"
        else
          _getopt_quote "${opts[@]}" -- "${params[@]}"
        fi
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
    # stderr and returns 1. (For first parse this should convert to exit
    # status 2.)  If there is no match at all, prints a message on stderr
    # and returns 2.
    declare a q="$1"
    declare -a matches
    shift
    for a; do
      if [[ $q == "$a" ]]; then
        # Exact match. Squash any other partial matches.
        matches=( "$a" )
        break
      elif [[ $flags == *a* && $q == -[^-]* && $q == -"$a" ]]; then
        # Exact alternative match. Squash any other partial matches.
        matches=( "$a" )
        break
      elif [[ $a == "$q"* ]]; then
        # Abbreviated match.
        matches+=( "$a" )
      elif [[ $flags == *a* && $q == -[^-]* && $a == -"$q"* ]]; then
        # Abbreviated alternative match.
        matches+=( "$a" )
      fi
    done
    case ${#matches[@]} in
      (0)
        [[ $flags == *q* ]] || \
        printf "$name: unrecognized option %s\n" >&2 \
          "$(_getopt_quote "$q")"
        return 2 ;;
      (1)
        printf '%s' "$matches"; return 0 ;;
      (*) 
        [[ $flags == *q* ]] || \
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
    declare s space q=\'
    for s; do
      printf "$space'%s'" "${s//$q/$q\\$q$q}"
      space=' '
    done
  }

  _getopt_quote_csh() {
    # Quotes arguments with single quotes, escaping inner single quotes,
    # bangs, backslashes and newlines
    declare s i c space
    for s; do
      echo -n "$space'"
      for ((i=0; i<${#s}; i++)); do
        c=${s:i:1}
        case $c in
          (\\|\'|!)
            echo -n "'\\$c'" ;;
          ($'\n')
            echo -n "\\$c" ;;
          (*)
            echo -n "$c" ;;
        esac
      done
      echo -n \'
      space=' '
    done
  }

  _getopt_help() {
    cat <<-EOT >&2
	
	Usage:
	 getopt optstring parameters
	 getopt [options] [--] optstring parameters
	 getopt [options] -o|--options optstring [options] [--] parameters
	
	Options:
	 -a, --alternative            Allow long options starting with single -
	 -h, --help                   This small usage guide
	 -l, --longoptions <longopts> Long options to be recognized
	 -n, --name <progname>        The name under which errors are reported
	 -o, --options <optstring>    Short options to be recognized
	 -q, --quiet                  Disable error reporting by getopt(3)
	 -Q, --quiet-output           No normal output
	 -s, --shell <shell>          Set shell quoting conventions
	 -T, --test                   Test for getopt(1) version
	 -u, --unquote                Do not quote the output
	 -V, --version                Output version information
	
	EOT
  }

  _getopt_main "$@"
  declare status=$?
  unset -f _getopt_main _getopt_err _getopt_parse _getopt_quote \
    _getopt_quote_csh _getopt_resolve_abbrev _getopt_split _getopt_help
  return $status
}

# vim:sw=2
