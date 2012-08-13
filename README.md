# pure-getopt

Do you have scripts that depend on getopt (from the util-linux package) for
long option parsing? Are you frustrated when you try to share those scripts
with your friends running OS X where getopt doesn't support long options?
Are you tired of telling them to install GNU getopt from MacPorts, Fink or
HomeBrew, just to run your script?

This is the problem that pure-getopt solves. It's a drop-in replacement for
GNU getopt, implemented in pure Bash. It makes no external calls and
faithfully reimplements GNU getopt features, including:

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

Cut and paste the entire function into your script.  Then call "getopt" as
you already were, except now it runs getopt internally instead of calling
to an external binary.

If you have a long script and you'd rather put the getopt function at the
bottom rather than the top, this pattern might be useful:

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
 * [bigeasy's getopt](https://github.com/bigeasy/getopt) -- another
   pure Bash implementation. I checked into it before writing pure-getopt 
   but quickly ran into issues. The coding style is pretty different from
   what I prefer, so I thought I had a better chance of success starting
   from scratch.
