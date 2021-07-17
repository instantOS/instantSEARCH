#!/bin/bash

# updates needed databases for instantsearch

if ! [ "$(whoami)" = "root" ]
then
    sudo update-instantsearch
    exit
fi

echo "updating instantsearch database"
echo "please do not close this window"
updatedb

LOCATEGROUP=plocate
DBFILE=/var/lib/plocate/plocate.db

if ! grep -q plocate /etc/group
then
    groupadd plocate
fi

chgrp $LOCATEGROUP $DBFILE.new

echo "finished updating databases"
