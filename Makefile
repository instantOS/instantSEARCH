PREFIX = /usr/

all: install

install:
	install -Dm 755 instantsearch.sh ${DESTDIR}${PREFIX}bin/instantsearch
	install -Dm 755 update-instantsearch.sh ${DESTDIR}${PREFIX}bin/update-instantsearch

uninstall:
	rm ${DESTDIR}${PREFIX}bin/instantsearch
	rm ${DESTDIR}${PREFIX}bin/update-instantsearch
