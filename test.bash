#!/bin/bash

source getopt.bash

normeval() {
  eval "set -- $1"
  if [[ $# -gt 0 ]]; then
    printf '%q ' % "$@"
    echo
  fi
}

want=$1
num=1

test() {
  declare myout myerr mynorm mystatus
  declare refout referr refnorm refstatus
  declare q=\' nl=$'\n'

  if [[ -z $want || $want -eq $num ]]; then
    declare t="$*"
    t=${t%%$nl*}
    [[ ${#t} -gt 68 ]] && t="${t::65}..."
    printf "%3s. Testing %s " "$((num++))" "$t"
  else
    (( num++ ))
    return
  fi

  refout=$(command getopt "$@" 2>/dev/null)
  refstatus=$?
  referr=$(command getopt "$@" 2>&1 >/dev/null)
  refnorm=$(normeval "$refout")

# set -x
# getopt "$@"
# exit
  myout=$(getopt "$@" 2>/dev/null)
  mystatus=$?
  myerr=$(getopt "$@" 2>&1 >/dev/null)
  mynorm=$(normeval "$myout")

  if [[ "$mystatus" == "$refstatus" && \
        "$mynorm" == "$refnorm" && \
        "$myerr" == "$referr" ]]
  then
    echo PASS
  elif [[ "$mystatus" == "$refstatus" && \
        "$mynorm" == "$refnorm" && \
        "$myerr" == *ambiguous* && \
        "$myerr" == "${referr/=* is /$q is }" ]]; then
    # Intentional difference between GNU getopt and pure-getopt:
    # gnu:  getopt: option '--de=foo' is ambiguous; possibilities: '--def'
    # pure: getopt: option '--de' is ambiguous; possibilities: '--def'
    echo PASS
  elif [[ "$mystatus" == "$refstatus" && \
        "$mynorm" == "$refnorm" && \
        "$myerr" == "${referr//invalid/unrecognized}" ]]; then
    # For no apparent reason, GNU getopt sometimes uses "invalid option"
    # instead of "unrecognized option"
    echo PASS
  else
    echo FAIL
    diff -u \
      --label reference \
      <(printf "EXIT: %s\nOUT: %s\nERR: %s\n" "$refstatus" "$refout" "$referr") \
      --label mine \
      <(printf "EXIT: %s\nOUT: %s\nERR: %s\n" "$mystatus" "$myout" "$myerr")
  fi
}

title() {
  if [[ -z $want ]]; then
    echo
    echo "$*"
    echo
  fi
}

title "Simple short options"

test -o xy:z:: --long=abc,def:,dez:: -- -x
test -o xy:z:: --long=abc,def:,dez:: -- -yfoo
test -o xy:z:: --long=abc,def:,dez:: -- -y foo
test -o xy:z:: --long=abc,def:,dez:: -- -z foo
test -o xy:z:: --long=abc,def:,dez:: -- -zfoo
test -o xy:z:: --long=abc,def:,dez:: -- -K

title "Simple long options"

test -o xy:z:: --long=abc,def:,dez:: -- --abc
test -o xy:z:: --long=abc,def:,dez:: -- --abc=foo
test -o xy:z:: --long=abc,def:,dez:: -- --abc foo
test -o xy:z:: --long=abc,def:,dez:: -- --def
test -o xy:z:: --long=abc,def:,dez:: -- --def=foo
test -o xy:z:: --long=abc,def:,dez:: -- --def foo
test -o xy:z:: --long=abc,def:,dez:: -- --dez
test -o xy:z:: --long=abc,def:,dez:: -- --dez=foo
test -o xy:z:: --long=abc,def:,dez:: -- --dez foo
test -o xy:z:: --long=abc,def:,dez:: -- --KK

title "Abbreviated long options"

test -o xy:z:: --long=abc,def:,dez:: -- --ab
test -o xy:z:: --long=abc,def:,dez:: -- --a
test -o xy:z:: --long=abc,def:,dez:: -- --ab foo
test -o xy:z:: --long=abc,def:,dez:: -- --de
test -o xy:z:: --long=abc,def:,dez:: -- --de=foo
test -o xy:z:: --long=abc,def:,dez:: -- --de foo

title "Alternative parsing"

test -a -o xy:z:: --long=abc,def:,dez:: -- -xyz -abc
test -a -o xy:z:: --long=abc,def:,dez:: -- -xyz -abc=foo
test -a -o xy:z:: --long=abc,def:,dez:: -- -xyz -abc foo
test -a -o xy:z:: --long=abc,def:,dez:: -- -xyz -def
test -a -o xy:z:: --long=abc,def:,dez:: -- -xyz -def=foo
test -a -o xy:z:: --long=abc,def:,dez:: -- -xyz -def foo
test -a -o xy:z:: --long=abc,def:,dez:: -- -xyz -dez
test -a -o xy:z:: --long=abc,def:,dez:: -- -xyz -dez=foo
test -a -o xy:z:: --long=abc,def:,dez:: -- -xyz -dez foo

title "Alternative parsing abbreviated long options"

test -a -o xy:z:: --long=abc,def:,dez:: -- -ab
test -a -o xy:z:: --long=abc,def:,dez:: -- -a
test -a -o xy:z:: --long=abc,def:,dez:: -- -ab foo
test -a -o xy:z:: --long=abc,def:,dez:: -- -de
test -a -o xy:z:: --long=abc,def:,dez:: -- -de=foo
test -a -o xy:z:: --long=abc,def:,dez:: -- -de foo

title "Empty command lines"

test -o xy:z:: --long=abc,def:,dez::
test -o xy:z:: --long=abc,def:,dez:: --
test -o xy:z:: --long=abc,def:,dez:: -- foo
test -o xy:z:: --long=abc,def:,dez:: -- foo bar

title "Error getopt invocations"

test
test -o
test --
test --long=foo

title "Quoting long arguments"

test -o xy:z:: --long=abc,def:,dez:: -- -y "$(<getopt.bash)"

# vim:sw=2
