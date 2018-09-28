#!/bin/bash

set -x

hg boo -d $(hg boo -q | egrep -v '(^tonytung|^master$)')
hg boo -d $(hg log -T "{join(bookmarks, '\n')}\n" -r 'obsolete() & (author(ttung) | author(tonytung))')
hg pull --hidden
hg boo -d $(hg oldbm)
#hg strip -r 'obsolete() & (!ancestors(!author(ttung)) & !ancestors(master))'

set -e

for rev in $(hg log -T '{node}\n' -r 'children(ancestors(master)) & (!ancestors(master)) & (author(ttung) | author(tonytung))'); do
    echo "Considering $rev..."
    if [ "$(hg log -r 'descendants('$rev') & !(author(ttung) | author(tonytung))')" != "" ]; then
        # has descendants that are not authored by me.
        if [ "$(hg log -r '('$rev' & !obsolete())')" != "" ]; then
            # not obsolete, rebase
            hg rebase --keep -d master -r "$rev::(descendants($rev) & (author(ttung) | author(tonytung)))"
            for rebasedrev in $(hg log -T '{node}\n' -r "$rev::(descendants($rev) & (author(ttung) | author(tonytung)))"); do
                hg debugobsolete $rebasedrev
            done
        fi
    else
        # strip everything that's obsolete first.
        while true; do
            hg strip -r 'descendants('$rev') & obsolete() & head()' || break
        done

        # we may have stripped everything, so make sure something is still there before continuing.
        if [ "$(hg log --hidden -r '('$rev' & !(hidden()))')" != "" ]; then
            hg rebase -d master -r 'descendants('$rev') & (!obsolete())'
        fi
    fi

    hg sl
done

set +e

hg boo -d $(hg oldbm)

# examine all the revs that are not in the master lineage, and are not part of a bookmark's history.
hg strip -r 'children(ancestors(master) & !master) & (!ancestors(master)) & (not ancestors(bookmark()))'

exit 0
