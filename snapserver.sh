#!/bin/sh

set | grep -E '^SNAPSERVER_'
set -eu

DBUS_UNIX_SOCKET="/host/run/user/$(id -u)/bus"
if [ -S "$DBUS_UNIX_SOCKET" ]; then
	export DBUS_SESSION_BUS_ADDRESS=unix:path="$DBUS_UNIX_SOCKET"
else
	echo "WARNING: Cannot advertise this snapserver instance since $DBUS_UNIX_SOCKET has not been mounted into the container" >&2
fi

envsubst "$(set | grep -Eo '^SNAPSERVER_[^=]+' | sed 's/^/$/')" < /etc/snapserver.conf > /tmp/snapserver.conf

set -x
exec snapserver -c /tmp/snapserver.conf --logging.sink=stdout --server.datadir=/data ${SNAPSERVER_OPTS:-} "$@"
