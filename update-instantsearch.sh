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

echo "updating plocate index"
LOCATEGROUP=plocate
DBFILE=/var/lib/plocate/plocate.db

plocate-build /var/lib/mlocate/mlocate.db $DBFILE.new
if ! grep -q plocate /etc/group
then
    groupadd plocate
fi
chgrp $LOCATEGROUP $DBFILE.new
mv $DBFILE.new $DBFILE

echo "finished updating databases"
