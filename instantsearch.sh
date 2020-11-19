#!/bin/bash

# file search GUI for plocate

if [ "$1" = "-s" ]; then
    echo "settings mode"
    instantinstall mlocate
    instantinstall plocate
    if ! systemctl status plocate-build.service; then
        if ! [ -e /etc/systemd/system/updatedb.service.wants/plocate-build.service ]; then
            if imenu -c "instantsearch needs the plocate build service to function. enable now?"; then
                if ! systemctl enable plocate-build.service; then
                    notify-send "failed to activate plocate build service"
                    exit
                fi
            else
                exit
            fi
        fi
    fi
    exit
fi

INCACHE="$HOME/.cache/instantos/instantsearch"
SCACHE="$HOME/.cache/instantos/searchterms"

    SEARCHSTRING="$(echo "recent files
search history
settings" | instantmenu -c -E -l 3 -bw 10 -q 'enter search term')"

[ -z "$SEARCHSTRING" ] && exit

if [ "$SEARCHSTRING" = "search history" ]; then

    if ! grep -q .... "$SCACHE"; then
        notify-send 'history empty, search something first'
        instantsearch &
        exit
    fi

    SEARCHSTRING="$(tac "$SCACHE" | perl -nE '$seen{$_}++ or print' | instantmenu -c -l 20 -bw 10 -q 'recent search terms')"
    [ -z "$SEARCHSTRING" ] && exit
elif [ "$SEARCHSTRING" = settings ]; then
    echo "opening settings"
    CHOICE="$(echo ":b 累Rescan files
:b Back" | instantmenu -w -1 -h -1 -c -l 20 -bw 10 -q 'instantSEARCH settings')"
    [ -z "$CHOICE" ] && exit
    case "$CHOICE" in
    *files)
        if pgrep updatedb; then
            imenu -m 'another scan is already running'
            exit
        fi
        instantutils open terminal -e bash -c 'echo "updating database" && sudo updatedb && echo "updating plocate index" && sudo plocate-build /var/lib/mlocate/mlocate.db /var/lib/mlocate/plocate.db'
        exit
        ;;
    *Back)
        instantsearch &
        exit
        ;;
    esac

fi

if [ "$SEARCHSTRING" = "recent files" ]; then
    if ! [ -e "$INCACHE" ]
    then
        notify-send 'file list empty, open something with instantSEARCH to fill it'
        instantsearch &
        exit
    fi

    RECENTFILE=true
    SEARCHSTRING="$(tac "$INCACHE" | perl -nE '$seen{$_}++ or print' | instantmenu -F -c -l 20 -bw 10 -q 'recent files')"
    [ -z "$SEARCHSTRING" ] && exit
    CHOICE="$SEARCHSTRING"
else
    searchitem() {
        {
            if grep -q '\.\*' <<<"$1"; then
                plocate -r -i "$1" --limit 2000
            else
                plocate -i "$1" --limit 2000
            fi
        } | perl -n -e '$x = $_; $x =~ tr%/%%cd; print length($x), " $_";' | sort -k 1n -k 2 | sed 's/^[0-9][0-9]* //'
    }

    if [ -z "$RECENTFILE" ]; then
        SEARCHLIST="$(searchitem "$SEARCHSTRING")"
        if [ -z "$SEARCHLIST" ]; then
            imenu -m "no results for $SEARCHSTRING"
            exit
        fi
        CHOICE="$(instantmenu -s -c -l 20 -bw 4 -w -1 -q 'search results' \
            <<<"$SEARCHLIST")"
        [ -z "$CHOICE" ] && exit
    fi
fi

opendir() {
    OPENCHOICE="$(echo ">>b Directory opener
:y 1: File manager
:b 2: Terminal
:r 3: Close" | instantmenu -E -ps 1 -i -n -l 20 -c -h -1 -wm -w -1 -q "$1" -a 3)"
    [ -z "$OPENCHOICE" ] && exit
    case "$OPENCHOICE" in
    *Close)
        exit
        ;;
    *Terminal)
        cd "$1" || exit 1
        instantutils open terminal &
        ;;
    *)
        instantutils open filemanager "$1" &
        ;;
    esac
}

if [ -d "$CHOICE" ]; then
    opendir "$CHOICE"
elif ! [ -e "$CHOICE" ]; then
    echo "file not existing"
    exit
else

    OPENCHOICE="$(echo ">>b File opener
:g 1 - Default
:y 2 - Xdg open
:b 3 - Rifle
:b 4 - Custom
:b 5 - Directory
:r 6 - Close" | instantmenu -E -ps 1 -l 20 -i -c -n -h -1 -wm -w -1 -q "$CHOICE" -a 3)"

    programopen() {
        OPENER="$(instantmenu_path |
            instantmenu -l 20 -c -h -1 -wm -w -1 -q "$CHOICE")"
        [ -z "$OPENER" ] && exit
        $OPENER "$CHOICE" &
        iconf instantsearch."$FILEMIME" "$OPENER"
    }

    [ -z "$OPENCHOICE" ] && exit

    FILEMIME="$(file -b --mime-type "$CHOICE" | sed 's/\//./g')"

    case "$OPENCHOICE" in
    *Default)
        if ! iconf instantsearch."$FILEMIME"; then
            notify-send "choose program to open filetype"
            programopen
        else
            eval "$(iconf instantsearch."$FILEMIME") \"$CHOICE\""
        fi
        ;;
    *open)
        xdg-open "$CHOICE"
        iconf instantsearch."$FILEMIME" xdg-open
        ;;
    *Rifle)
        rifle "$CHOICE"
        iconf instantsearch."$FILEMIME" rifle
        ;;
    *Directory)
        opendir "${CHOICE%*/}"
        ;;
    *Close)
        exit
        ;;
    *)
        programopen
        ;;
    esac

fi

echo "$SEARCHSTRING" >>"$SCACHE"

if [ "$(wc -l "$SCACHE" | grep -o '^[0-9]*')" -gt 500 ]; then
    sed -i '1,100d' "$SCACHE"
fi

echo "$CHOICE" >>"$INCACHE"
if [ "$(wc -l "$INCACHE" | grep -o '^[0-9]*')" -gt 500 ]; then
    sed -i '1,100d' "$INCACHE"
fi
