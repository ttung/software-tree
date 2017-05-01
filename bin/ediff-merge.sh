#!/bin/sh

# args=`getopt H -- "$@"`
# eval set -- "$args"

# while true; do
#     case "$1" in
#         -H) disable_vc_hg=true; shift;;
#         --) shift ; break ;;
#     esac
# done

if [ "$EDITOR" == "" ]; then
    EDITOR=emacs
fi

if [ `uname -s` == "Linux" ]; then
    stat_cmd='stat -c %Y'
else
    stat_cmd='stat -f %m'
fi

pre_mtime=`$stat_cmd "$4"`

if [[ -e "$1" ]]; then
    $EDITOR --eval "(ediff-merge-files-with-ancestor \"$2\" \"$3\" \"$1\" nil \"$4\")"
else
    $EDITOR --eval "(ediff-merge-files \"$2\" \"$3\" nil \"$4\")"
fi

post_mtime=`$stat_cmd "$4"`

if [ $? -eq 0 ]; then
    if [ $pre_mtime == $post_mtime ]; then
        exit 1
    fi
    exit 0
fi

exit 1
