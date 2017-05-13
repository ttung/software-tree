#!/bin/sh

if [ $# -lt 1 ]; then
    echo "Usage: $0 <branch>"
    echo "Moves branch <branch> to the current HEAD and switches to it."
    exit 1
fi

function git_pull_rev() {
    local branch_position=`git rev-parse -q --verify --short refs/heads/$1`
    if [ -z "${branch_position}" ]; then
        echo "$1 is not a valid branch"
        exit 1
    fi

    echo "branch $1 is currently at $branch_position.  moving to `git rev-parse --short HEAD`"

    git update-ref refs/heads/$1 HEAD
    git co $1
}

git_pull_rev $1
