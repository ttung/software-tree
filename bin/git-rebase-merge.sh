#!/bin/sh

if [ $# -ne 2 ]; then
    echo "Usage: $0 <ancestor-branch-name> <descendent-branch-name>"
    exit 1
fi

function verify_branch_exists() {
    local branch_position=`git rev-parse -q --verify --short refs/heads/$1`
    if [ -z "${branch_position}" ]; then
        echo "$1 is not a valid branch"
        exit 1
    fi
}

function git_rebase_merge() {
    verify_branch_exists $1
    verify_branch_exists $2

    # find the old ancestor
    # for rev in `git reflog show --format=%H $1 | sed -n '$!p'`; do
    for rev in `git reflog show --format=%H $1`; do
        git merge-base --is-ancestor $rev $2
        if [ $? -eq 0 ]; then
            # found it!
            echo "Found old ancestor: $rev"
            local old_ancestor=$rev
            break
        fi
    done

    if [ -z "${old_ancestor}" ]; then
        echo "Couldn't find previous ancestor for $2 on branch $1"
        exit 2
    fi

    git rebase -p --onto $1 $old_ancestor $2
}

git_rebase_merge $1 $2
