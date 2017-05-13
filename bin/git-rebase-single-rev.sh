#!/bin/sh

if [ $# -lt 2 ]; then
    echo "Usage: $0 <head> <branch> ..."
    exit 1
fi

function git_rebase_single_rev() {
    if [ $3 ]; then
        echo git rebase --onto $1 $2^ $2
    fi
    git rebase --onto $1 $2^ $2
}

verbose=$(($# > 2))

while [ $# -ge 2 ]; do
    git_rebase_single_rev $1 $2 $3
    errcode=$?
    shift
    if [ $errcode -ne 0 ]; then
        # if there's more revs left to do, then print out a command for continuing
        if [ $# -ge 2 ]; then
            echo "Remaining revs: $*"
        fi
        break
    fi
done
