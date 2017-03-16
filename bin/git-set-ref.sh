#!/bin/sh

if [ $# -lt 2 ]; then
    echo "Usage: $0 [-f] <branch> <revspec>"
    exit 1
fi

function git_set_rev() {
    local current_branch=`git branch | egrep '^\*' | sed -E 's/\* //'`

    if [ "$current_branch" == "$1" ]; then
        # is the workspace clean?
        local STATUS=$(git status 2>/dev/null)

        if ([ "$3" != "true" ] &&
                ([[ "$STATUS" == *'Changes to be committed:'* ]] ||
                    [[ "$STATUS" == *'Changed but not updated:'* ]])); then
            echo "You have uncommitted changes on this tree"
            exit 2
        fi
    fi

    echo "Updating refs/heads/$1 to $2"
    git update-ref refs/heads/$1 $2
}

args=`getopt f -- "$@"`
eval set -- "$args"

while true; do
    case "$1" in
        -f) force=true; shift;;
        --) shift ; break ;;
    esac
done

git_set_rev $1 $2 $force
