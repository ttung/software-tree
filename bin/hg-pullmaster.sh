#!/bin/bash

set -x

if hg log -r master > /dev/null 2> /dev/null; then
    trunk=master
elif hg log -r trunk > /dev/null 2> /dev/null; then
    trunk=trunk
fi

hg boo -d $(hg boo -q | egrep -v '^(ttung|tonytung|master$|trunk$)')
hg boo -d $(hg log -T "{join(bookmarks, '\n')}\n" -r 'obsolete() & (author(ttung) | author(tonytung))')
hg pull --hidden
hg boo -d $(hg log -T "{join(bookmarks, '\n')}\n" -r "ancestors(${trunk}) & bookmark()" | egrep -v ^${trunk}$)

set -e

for rev in $(hg log -T '{node}\n' -r "children(ancestors(${trunk})) & (!ancestors(${trunk})) & (author(ttung) | author(tonytung))"); do
    echo "Considering $rev..."
    if [ "$(hg log -r 'descendants('$rev') & !(author(ttung) | author(tonytung))')" != "" ]; then
        # has descendants that are not authored by me.
        if [ "$(hg log -r '('$rev' & !obsolete())')" != "" ]; then
            # not obsolete, rebase
            hg rebase --keep -d "${trunk}" -r "$rev::(descendants($rev) & (author(ttung) | author(tonytung)))"
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
            hg rebase -d "${trunk}" -r 'descendants('$rev') & (!obsolete())'
        fi
    fi

    hg sl
done

set +e

hg boo -d $(hg log -T "{join(bookmarks, '\n')}\n" -r "ancestors(${trunk}) & bookmark()" | egrep -v ^${trunk}$)

# examine all the revs that are not in the trunk/master lineage, and are not part of a bookmark's history.
hg strip -r "children(ancestors(${trunk}) & !${trunk}) & (!ancestors(${trunk})) & (not ancestors(bookmark()))" || true
