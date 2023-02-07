#!/bin/sh

set | grep -E '^SNAPSERVER_'
set -eu

envsubst "$(set | grep -Eo '^SNAPSERVER_[^=]+' | sed 's/^/$/')" < /etc/snapserver.conf > /tmp/snapserver.conf

if [ "$SNAPSERVER_SOURCE_CREATE_FIFO" ]; then
	echo "Creating snapserver source fifo at $SNAPSERVER_SOURCE_CREATE_FIFO"
	[ -p "$SNAPSERVER_SOURCE_CREATE_FIFO" ] || mkfifo -m 640 "$SNAPSERVER_SOURCE_CREATE_FIFO"
	if [ "$SNAPSERVER_SOUND_TEST" = true ]; then
		echo Playing test sound continuously
		sox -V -r 48000 -n -b 16 -c 2 /tmp/testsound.wav synth 30 sin 0+19000 sin 1000+20000 vol -10db remix 1,2 channels 2
		while true; do
			cat /tmp/testsound.wav > "$SNAPSERVER_SOURCE_CREATE_FIFO"
			sleep 20
		done &
	fi
fi

if [ "$SNAPSERVER_START_SOUND_ENABLED" = true ] && echo "$SNAPSERVER_SOURCE" | grep -Eq '^pipe://'; then
	(
		sleep 3
		echo Playing start sound
		FIFO="$(echo "$SNAPSERVER_SOURCE" | sed -E 's!^pipe://!!; s!\?.*$!!')" &&
		sox -V -r 48000 -n -b 16 -c 2 /tmp/start.wav synth 3 sin 0+15000 sin 1000+80000 vol -10db remix 1,2 channels 2 &&
		cat /tmp/start.wav > "$FIFO"
	) &
fi

set -x
exec snapserver -c /tmp/snapserver.conf ${SNAPSERVER_OPTS:-} "$@"
