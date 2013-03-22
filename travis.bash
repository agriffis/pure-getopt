#!/bin/bash

status=0

for b in $BASHES; do
    echo
    echo ==================
    echo $b
    echo ==================
    $b test.bash || status=$?
done

exit $status
