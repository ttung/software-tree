#!/bin/bash

set -x

hg boo -d $(hg boo -q | egrep -v '(^tonytung|^master$)')
hg pull --hidden
hg boo -d $(hg oldbm)
#hg strip -r 'obsolete() & (!ancestors(!author(ttung)) & !ancestors(master))'

set -e

for rev in $(hg log -T '{node}\n' -r 'children(ancestors(master)) & (!ancestors(master)) & (!obsolete()) & (author(ttung) | author(tonytung))'); do
    echo "Considering $rev..."
    if [ "$(hg log -r 'descendants('$rev') & !(author(ttung) | author(tonytung))')" != "" ]; then
        # has descendants that are not authored by me.
        hg rebase --keep -d master -r "$rev::(descendants($rev) & (author(ttung) | author(tonytung)))"
        for rebasedrev in $(hg log -T '{node}\n' -r "$rev::(descendants($rev) & (author(ttung) | author(tonytung)))"); do
            hg debugobsolete $rebasedrev
        done
    else
        hg rebase -d master -s $rev
    fi
done

set +e

hg boo -d $(hg oldbm)

# examine all the revs that are not in the master lineage, and are not part of a bookmark's history.
for rev in $(hg log -T '{node}\n' -r 'children(ancestors(master)) & (!ancestors(master)) & (not (bookmark() or ancestors(bookmark())))'); do
    if [ "$(hg log -r 'descendants('$rev') & !(author(ttung) | author(tonytung))')" == "" ]; then
        hg strip $rev
    fi
done
