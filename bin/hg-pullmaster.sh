#!/bin/bash

hg boo -d $(hg boo -q | egrep -v '(^tonytung|^master$)')
hg pull --hidden
hg boo -d $(hg oldbm)
hg strip -r 'obsolete() & (!ancestors(!author(ttung)) & !ancestors(master))'

set -e

for rev in $(hg log -T '{node}\n' -r 'children(ancestors(master)) & (!ancestors(master)) & (author(ttung) | author(tonytung))'); do
    echo "Considering $rev..."
    if [ "$(hg log -r 'descendants('$rev') & !(author(ttung) | author(tonytung))')" != "" ]; then
        # has descendants that are not authored by me.
        hg rebase --keep -d master -r "$rev::(descendants($rev) & (author(ttung) | author(tonytung)))"
    else
        hg rebase -d master -s $rev
    fi
done

set +e

hg boo -d $(hg oldbm)
#hg strip -r 'obsolete() or unstable()'
hg strip -r 'not (bookmark() or ancestors(bookmark()) or author(ttung))'
