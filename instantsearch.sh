#!/bin/bash

# file search GUI for plocate

if [ "$1" = "-s" ]; then
    echo "settings mode"
    instantinstall mlocate
    instantinstall plocate
    exit
fi

INCACHE="$HOME/.cache/instantos/instantsearch"

if [ -e "$INCACHE" ]; then
    SEARCHSTRING="$(echo "recent files" | instantmenu -c -l 1 -bw 10 -q 'enter search term')"
else
    SEARCHSTRING="$(echo "" | instantmenu -c -l 1 -bw 10 -q 'enter search term')"
fi

[ -z "$SEARCHSTRING" ] && exit

if [ "$SEARCHSTRING" = "recent files" ]; then
    RECENTFILE=true
    SEARCHSTRING="$(tac "$INCACHE" | perl -nE '$seen{$_}++ or print' | instantmenu -c -l 20 -bw 10 -q 'recent files')"
    [ -z "$SEARCHSTRING" ] && exit
    CHOICE="$SEARCHSTRING"
else
    # TODO sort by depth
    searchitem() {
        if grep -q '\.\*' <<<"$1"; then
            echo "searching with regex enabled"
            plocate -r -i "$1" --limit 2000
        else
            plocate -i "$1" --limit 2000
        fi
    }

    if [ -z "$RECENTFILE" ]; then
        SEARCHLIST="$(searchitem "$SEARCHSTRING")"
        if [ -z "$SEARCHLIST" ]; then
            imenu -m "no results for $SEARCHSTRING"
            exit
        fi
        CHOICE="$(instantmenu -c -l 20 -bw 4 -w -1 -q 'search results' \
            <<<"$SEARCHLIST")"
        [ -z "$CHOICE" ] && exit
    fi
fi

if [ -d "$CHOICE" ]; then

    OPENCHOICE="$(echo ">>b Directory opener
:y File manager
:b Terminal
:r Close" | instantmenu -ps 1 -l 20 -c -h -1 -wm -w -1 -q "$CHOICE")"
    case "$OPENCHOICE" in
    *close)
        exit
        ;;
    *terminal)
        cd "$CHOICE" || exit 1
        instantutils open terminal
        ;;
    *)
        instantutils open filemanager "$CHOICE" &
        ;;
    esac

    exit
elif ! [ -e "$CHOICE" ]; then
    echo "file not existing"
    exit
fi

OPENCHOICE="$(echo ">>b File opener
:y xdg open
:b rifle
:b custom
:r Close" | instantmenu -ps 1 -l 20 -c -h -1 -wm -w -1 -q "$CHOICE")"

[ -z "$OPENCHOICE" ] && exit

case "$OPENCHOICE" in
*open)
    xdg-open "$CHOICE"
    ;;
*rifle)
    rifle "$CHOICE"
    ;;
*close)
    exit
    ;;
*)
    OPENER="$(instantmenu_path |
        instantmenu -l 20 -c -h -1 -wm -w -1 -q "$CHOICE")"
    [ -z "$OPENER" ] && exit
    $OPENER "$CHOICE" &
    ;;
esac

echo "$CHOICE" >>"$INCACHE"
if [ "$(wc -l "$INCACHE" | grep -o '^[0-9]*')" -gt 500 ]; then
    sed -i '1,100d' "$INCACHE"
fi
