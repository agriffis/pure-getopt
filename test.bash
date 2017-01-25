#!/bin/bash

source getopt.bash

evalbash() {
  eval "set -- $1"
  if [[ $# -gt 0 ]]; then
    printf '%q ' % "$@"
    echo
  fi
}

evalcsh() {
  ARGS=$1 tcsh -c '
    eval set argv = \( $ARGS:q \)
    echo $1:q
    echo $2:q
    echo $3:q
    echo $4:q
    '
}

status=0
want=$1
num=1

test() {
  declare myout myerr mynorm mystatus
  declare refout referr refnorm refstatus
  declare q=\' nl=$'\n' evalnorm=evalbash

  if [[ -z $want || $want -eq $num ]]; then
    declare t="$*"
    t=${t%%$nl*}
    [[ ${#t} -gt 68 ]] && t="${t::65}..."
    printf "%3s. Testing %s%s " "$((num++))" \
      "${GETOPT_COMPATIBLE+GETOPT_COMPATIBLE }${POSIXLY_CORRECT+POSIXLY_CORRECT }" \
      "$t"
  else
    (( num++ ))
    return $status
  fi

  if [[ "$1 $2" == '-s csh' || "$1 $2" == '-s tcsh' ]]; then
    evalnorm=evalcsh
  fi

  refout=$(command getopt "$@" 2>/dev/null)
  refstatus=$?
  referr=$(command getopt "$@" 2>&1 >/dev/null)
  refnorm=$($evalnorm "$refout")

  myout=$(getopt "$@" 2>/dev/null)
  mystatus=$?
  myerr=$(getopt "$@" 2>&1 >/dev/null)
  mynorm=$($evalnorm "$myout")

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
    # gnu:  getopt: option '--x=foo' is ambiguous; possibilities: '--xy' '--xz'
    # pure: getopt: option '--x' is ambiguous; possibilities: '--xy' '--xz'
    echo PASS
  else
    echo FAIL
    diff -u \
      --label reference \
      <(printf "EXIT: %s\nOUT: %s\nERR: %s\n" "$refstatus" "$refout" "$referr") \
      --label mine \
      <(printf "EXIT: %s\nOUT: %s\nERR: %s\n" "$mystatus" "$myout" "$myerr")
    status=1
  fi

  # These get stuck
  unset GETOPT_COMPATIBLE POSIXLY_CORRECT
}

test_no_status() {
  declare ostatus=$status
  test "$@"
  status=$ostatus
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
# Test exact match against partial match
test -o '' --long=abc,abcd -- --abc

title "Empty command lines"

test -o xy:z:: --long=abc,def:,dez::
test -o xy:z:: --long=abc,def:,dez:: --
test -o xy:z:: --long=abc,def:,dez:: -- foo
test -o xy:z:: --long=abc,def:,dez:: -- foo bar

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
# Test exact match against partial match
test -a -o '' --long=abc,abcd -- -abc

title "Alternative parsing abbreviated long options"

test -a -o xy:z:: --long=abc,def:,dez:: -- -ab
test -a -o xy:z:: --long=abc,def:,dez:: -- -a
test -a -o xy:z:: --long=abc,def:,dez:: -- -ab foo
test -a -o xy:z:: --long=abc,def:,dez:: -- -de
test -a -o xy:z:: --long=abc,def:,dez:: -- -de=foo
test -a -o xy:z:: --long=abc,def:,dez:: -- -de foo

title "Quoting long arguments"

test -o xy:z:: --long=abc,def:,dez:: -- -y "$(head -n 200 getopt.bash)"

title "GETOPT_COMPATIBLE and POSIXLY_CORRECT"

# Baseline reorders options before non-option params: -x -y -- foo
test -o xy -- -x foo -y
# Leading dash doesn't reorder: -x foo -y
test -o -xy -- -x foo -y
# ..except in compatibility mode: -x -y -- foo
GETOPT_COMPATIBLE= test -xy -x foo -y
# Leading plus does POSIXLY_CORRECT: -x -- foo -y
test -o +xy -- -x foo -y
POSIXLY_CORRECT= test -o xy -- -x foo -y
POSIXLY_CORRECT= test -o +xy -- -x foo -y
# ..except in compatibility mode: -x -y -- foo
GETOPT_COMPATIBLE= test +xy -x foo -y
# and POSIXLY_CORRECT overrides GETOPT_COMPATIBLE: -x -- foo -y
GETOPT_COMPATIBLE= POSIXLY_CORRECT= test xy -x foo -y

title "Error getopt invocations"

test
test -o
test --
test --long=foo

title "Getopt help"

test_no_status -h
test_no_status --help

title "Getopt version with -T"

test -T
GETOPT_COMPATIBLE=1 test -T
# GETOPT_COMPATIBLE empty string should work too
GETOPT_COMPATIBLE= test -T

title "Setting shell with -s"

test -s sh -o xy:z:: --long=abc,def:,dez:: -- -x -y a\\b\ c
test -s bash -o xy:z:: --long=abc,def:,dez:: -- -x -y a\\b\ c
test -s foo -o xy:z:: --long=abc,def:,dez:: -- -x -y a\\b\ c

if type tcsh &>/dev/null; then
  test -s csh -o xy:z:: --long=abc,def:,dez:: -- -x -y a\\b\ c
  test -s tcsh -o xy:z:: --long=abc,def:,dez:: -- -x -y a\\b\ c
fi

title "Regression tests"

# Spelling error $flgas.
# The bug causes -a (and any other flags) to be dropped.
# https://github.com/agriffis/pure-getopt/issues/2
test -a -o -xy:z:: --long=abc,def:,dez:: -- -ab

exit $status

# vim:sw=2
