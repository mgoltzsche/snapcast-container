#!/bin/sh

set | grep -E '^SNAPSERVER_'
set -eu

envsubst "$(set | grep -Eo '^SNAPSERVER_[^=]+' | sed 's/^/$/')" < /etc/snapserver.conf > /tmp/snapserver.conf

if [ "$SNAPSERVER_SOURCE_CREATE_FIFO" ]; then
	echo "Creating snapserver source fifo at $SNAPSERVER_SOURCE_CREATE_FIFO"
	[ -p "$SNAPSERVER_SOURCE_CREATE_FIFO" ] || mkfifo -m 640 "$SNAPSERVER_SOURCE_CREATE_FIFO"
	echo Generating a bit noise to initialize snapserver
	timeout 1 sh -c 'cat /dev/urandom > "$SNAPSERVER_SOURCE_CREATE_FIFO"' || true
fi

set -x
exec snapserver -c /tmp/snapserver.conf ${SNAPSERVER_OPTS:-} "$@"
