#!/bin/sh

set | grep -E '^SNAPSERVER_'
set -eu

envsubst "$(set | grep -Eo '^SNAPSERVER_[^=]+' | sed 's/^/$/')" < /etc/snapserver.conf > /tmp/snapserver.conf

set -x
exec snapserver -c /tmp/snapserver.conf --logging.sink=stdout --server.datadir=/data ${SNAPSERVER_OPTS:-} "$@"
