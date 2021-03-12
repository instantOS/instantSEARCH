#!/bin/bash

# file search GUI for plocate

INCACHE="$HOME/.cache/instantos/instantsearch"
SCACHE="$HOME/.cache/instantos/searchterms"

# remove non-existing files from cache
cleancache() {
    echo "cleaning cache"
    [ -e "${INCACHE}.new" ] && rm "${INCACHE}.new"
    while read -r file; do
        if [ -e "$file" ]; then
            echo "keeping $file"
            echo "$file" >>"${INCACHE}.new"
        else
            echo "removing $file from cache"
        fi
    done <<<"$(sort -u "$INCACHE")"
    cat "${INCACHE}.new" >"$INCACHE"
}

checkdb() {
    ERRORMSG="$(plocate thisisatextthatisntsupposedtobefounditsjustatestpleasedontcreateafilecalledthis /dev/null 2>&1)"
    [ -z "$ERRORMSG" ] && return 0
    if grep -q '/var/lib/plocate/plocate.db:' <<<"$ERRORMSG" ||
        grep -q 'pread' <<<"$ERRORMSG" ||
        grep -iq 'inappropriate' <<<"$ERRORMSG"; then
        return 1
    else
        return 0
    fi
}

case "$1" in
# check health of all requirements
"-H")

    instantinstall plocate || exit 1

    if ! groups | grep -q plocate; then
        PUSER="$(whoami)"
        imenu -c 'instantsearch is missing some configuration. repair now?' || exit
        instantsudo groupadd plocate
        instantsudo usermod -aG plocate "$PUSER" || exit 1
        imenu -c 'changes will be applied upon reboot. reboot now?' || exit
        instantshutdown reboot
    fi

    if ! systemctl is-enabled plocate-updatedb.timer; then
        if imenu -c "instantsearch needs the plocate build service to function. enable now?"; then
            if ! instantsudo systemctl enable plocate-updatedb.timer; then
                if ! systemctl list-unit-files | grep plocate-updatedb.timer; then
                    imenu -m 'error: plocate service not found, is plocate installed on your system?'
                else
                    notify-send "failed to activate plocate build service"
                fi
                exit
            fi
        fi
    fi

    if ! checkdb; then
        if echo 'instantSEARCH needs to scan your drives
This can take a long time on systems with slow storage
but it will be a one time process
Start scan now?' | imenu -C; then
            echo "generating first index"
            instantutils open terminal -e bash -c "sudo update-instantsearch"
        fi
    fi

    exit
    ;;
-d)
    if [ -z "$2" ] || ! [ -e "$2" ]; then
        echo "usage: instantsearch -d directory"
        exit 1
    fi
    DPREFIX="$(realpath "$2")/.*"
    ;;
-c)
    echo "cleaning instantsearch cache"
    cleancache
    exit
    ;;
-U)
    echo "updating instantsearch"
    update-instantsearch
    exit
    ;;
--help)
    echo 'usage: instantsearch
    -H healthcheck
    -U update database
    -c clean cache'
    exit
    ;;
esac

if [ -z "$DPREFIX" ]; then
    SEARCHTITLE="enter search term"
else
    SEARCHTITLE="search through $DPREFIX"
fi

SEARCHSTRING="$(echo "recent files
search history
settings" | instantmenu -c -E -l 3 -bw 10 -q "$SEARCHTITLE")"

[ -z "$SEARCHSTRING" ] && exit

rescanfiles() {
    echo "rescanning"
    if pgrep updatedb; then
        imenu -m 'another scan is already running'
        exit
    fi
    instantutils open terminal -e bash -c "echo 'instantsearch updater' && sudo update-instantsearch && notify-send 'finished scanning files'"
    cleancache
}

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
        rescanfiles
        exit
        ;;
    *Back)
        instantsearch &
        exit
        ;;
    esac

fi

if [ "$SEARCHSTRING" = "recent files" ]; then
    if ! [ -e "$INCACHE" ]; then
        notify-send 'file list empty, open something with instantSEARCH to fill it'
        instantsearch &
        exit
    fi

    RECENTFILE=true
    SEARCHSTRING="$(tac "$INCACHE" | perl -nE '$seen{$_}++ or print' | instantmenu -F -s -c -l 20 -bw 10 -q 'recent files')"
    [ -z "$SEARCHSTRING" ] && exit
    CHOICE="$SEARCHSTRING"
else
    searchitem() {
        {
            if grep -q '\.\*' <<<"$1" || [ -n "$DPREFIX" ]; then
                plocate -r -i "$DPREFIX$1" --limit 2000
            else
                plocate -i "$1" --limit 2000
            fi
        } | perl -n -e '$x = $_; $x =~ tr%/%%cd; print length($x), " $_";' | sort -k 1n -k 2 | sed 's/^[0-9][0-9]* //'
    }

    if [ -z "$RECENTFILE" ]; then
        SEARCHLIST="$(searchitem "$SEARCHSTRING")"
        if [ -z "$SEARCHLIST" ]; then
            if ! checkdb; then
                instantsearch -H
            else
                imenu -m "no results for $SEARCHSTRING"
            fi
            exit
        fi
        CHOICE="$(instantmenu -s -c -l 20 -bw 4 -w -1 -q "search results for $SEARCHSTRING" \
            <<<"$SEARCHLIST")"
        [ -z "$CHOICE" ] && exit
    fi
fi

opendir() {
    OPENCHOICE="$(echo ">>b Directory opener
:y 1: File manager
:b 2: Terminal
:b 3: Search
:b 4 - Xdragon
:r 5: Close" | instantmenu -ps 1 -i -n -l 20 -c -h -1 -wm -w -1 -q "$1" -a 3)"
    [ -z "$OPENCHOICE" ] && exit
    case "$OPENCHOICE" in
    *Close)
        exit
        ;;
    *Terminal)
        cd "$1" || exit 1
        instantutils open terminal &
        ;;
    *Search)
        instantsearch -d "$1"
        exit
        ;;
    *Xdragon)
        xdragon "$1"
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
    if echo "$CHOICE not found
The file might have been moved or deleted. 
Would you like to rescan your files to account for moved files?" | imenu -C "file not found error"; then
        rescanfiles
        exit
    fi

    exit
else

    OPENCHOICE="$(echo ">>b File opener
:g 1 - Default
:y 2 - Xdg open
:b 3 - Rifle
:b 4 - Custom
:b 5 - Directory
:b 6 - Xdragon
:r 7 - Close" | instantmenu -ps 1 -l 20 -i -c -n -h -1 -wm -w -1 -q "$CHOICE" -a 3)"

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
        opendir "${CHOICE%/*}"
        ;;
    *Xdragon)
        xdragon "$1"
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
