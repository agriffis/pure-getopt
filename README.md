# pure-getopt

[![Build Status](https://secure.travis-ci.org/agriffis/pure-getopt.png?branch=master)](http://travis-ci.org/agriffis/pure-getopt)

pure-getopt is a drop-in replacement for GNU getopt, implemented in pure
Bash compatible back to 2.05b. It makes no external calls and faithfully
reimplements GNU getopt features, including:

 * all three calling forms in the synopsis
 * all getopt options
 * matching error messages
 * matching return codes
 * proper handling of abbreviated long options
 * alternative parsing mode (long options with single dash)
 * GETOPT_COMPATIBLE flag
 * POSIXLY_CORRECT flag
 * leading + or - on options string

# How to use it

Cut and paste the entire function into your script, prior to calling
"getopt". Done! :-)

I don't recommend sourcing getopt.bash into your script. The problem is
that you've just traded a dependency on GNU getopt for a dependency on
pure-getopt. Most of the time it should be okay to just insert the function
directly in your script.

If you have a long script and you'd rather put the getopt function at the
bottom rather than the top, this pattern might be useful:

```bash
#!/bin/bash

main() {
    declare argv
    argv=$(getopt -o xy:z:: --long foo,bar:,baz:: -- "$@") || return
    eval "set -- $argv"

    declare a
    for a; do
        case $a in
            ...
        esac
    done
}

# INSERT getopt function here
getopt() {
    ...
}

# CALL main at very bottom, passing script args
main "$@"
```

# Differences between pure-getopt and GNU getopt

The only intentional divergences between pure-getopt and GNU getopt are
either inconsequential or due to bugs in GNU getopt:

 1. GNU getopt mishandles ambiguities in abbreviated long options, for
    example this doesn't produce an error message:
    
        getopt -o '' --long xy,xz -- --x

    but this does produce an error message:

        getopt -o '' --long xy,xz: -- --x

    Pure-getopt generates an error message in both cases, diverging from
    GNU getopt to fix this bug.

 2. In the case of an ambiguous long option with an argument, GNU getopt
    generates an error message that includes the argument:

        getopt: option '--x=foo' is ambiguous; possibilities: '--xy' '--xz'

    Pure-getopt considers this a bug in GNU getopt, since the value might
    be very long and inappropriate for printing to the screen, and since
    GNU getopt ordinarily omits the value in its error messages.
    Pure-getopt's error message in this case is:

        getopt: option '--x' is ambiguous; possibilities: '--xy' '--xz'

 3. Pure-getopt uses a different method of quoting the output. The result
    should be the same as GNU getopt when eval'd by the shell. If you find
    a case where it's different, please report it as a bug!

 4. Pure-getopt has a test suite; GNU getopt in util-linux does not.

# References

 * [getopt in util-linux](http://software.frodo.looijaard.name/getopt/)
