#!/bin/sh

set | grep -E '^SNAPSERVER_'
set -eu

envsubst "$(set | grep -Eo '^SNAPSERVER_[^=]+' | sed 's/^/$/')" < /etc/snapserver.conf > /tmp/snapserver.conf

if [ "$SNAPSERVER_SOURCE_CREATE_FIFO" ]; then
	echo "Creating snapserver source fifo at $SNAPSERVER_SOURCE_CREATE_FIFO"
	[ -p "$SNAPSERVER_SOURCE_CREATE_FIFO" ] || mkfifo -m 640 "$SNAPSERVER_SOURCE_CREATE_FIFO"
	echo Generating a bit noise to initialize snapserver
	if [ "$SNAPSERVER_SOUND_TEST" = true ]; then
		sox -V -r 48000 -n -b 16 -c 2 /tmp/testsound1.wav synth 30 sin 0+19000 sin 1000+20000 vol -10db remix 1,2 channels 2
		sox -V -r 48000 -n -b 16 -c 2 /tmp/testsound2.wav synth 3 sin 0+15000 sin 1000+80000 vol -10db remix 1,2 channels 2
		while true; do
			cat /tmp/testsound1.wav > "$SNAPSERVER_SOURCE_CREATE_FIFO"
			cat /tmp/testsound2.wav > "$SNAPSERVER_SOURCE_CREATE_FIFO"
			sleep 1
		done &
	fi
fi

set -x
exec snapserver -c /tmp/snapserver.conf ${SNAPSERVER_OPTS:-} "$@"
