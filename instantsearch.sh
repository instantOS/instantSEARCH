#!/bin/bash

# file search GUI for plocate

SEARCHSTRING="$(imenu -i 'search file')"
[ -z "$SEARCHSTRING" ] && exit

# TODO sort by depth
searchitem() {
    if grep -q '\.\*' <<<"$1"; then
        plocate "$1" --limit 2000
    else
        plocate -r -i "$1" --limit 2000
    fi
}

SEARCHLIST="$(searchitem "$SEARCHSTRING")"
CHOICE="$(instantmenu -c -l 20 -bw 4 -w -1 -q 'search results' \
    <<<"$SEARCHLIST")"

if [ -d "$CHOICE" ]
then
    echo "open in file manager
open in terminal"
    instantutils open filemanager "$CHOICE" &
    exit
elif ! [ -e "$CHOICE" ]
then
    echo "file not existing"
    exit
fi


