#!/bin/sh

set | grep -E '^SNAPSERVER_'
set -eu

sourceName() {
	echo "$1" | grep -Eo '(\?|&)name=[^&]+' | sed -E 's/(\?|&)name=//'
}

# Generate source config
if [ ! "${SNAPSERVER_SOURCE_CONFIG:-}" ]; then
	SNAPSERVER_SOURCE_CONFIG="source = $SNAPSERVER_SOURCE"
	if [ "${SNAPSERVER_SOURCE_LIBRESPOT_ENABLED:-true}" = true ]; then
		DEVICE_NAME=Snapcast
		if [ "${NODE_NAME:-}" ]; then
			DEVICE_NAME="Snapcast on $NODE_NAME"
		fi
		# TODO: limit librespot cache storage size
		# TODO: remove codec=null to allow selecting sources separately, once the meta source can be default, see https://github.com/badaix/snapcast/issues/1316
		SNAPSERVER_SOURCE_CONFIG="$SNAPSERVER_SOURCE_CONFIG&codec=null
source = librespot:///usr/local/bin/librespot?name=LibreSpot&bitrate=320&sampleformat=44100:16:2&devicename=$DEVICE_NAME&normalize=true&autoplay=true&killall=true&cache=/tmp/librespot-cache&codec=null
source = meta:///$(sourceName "$SNAPSERVER_SOURCE")/LibreSpot?name=mix
"
	fi
	export SNAPSERVER_SOURCE_CONFIG
fi

# Generate snapserver config file
envsubst "$(set | grep -Eo '^SNAPSERVER_[^=]+' | sed 's/^/$/')" < /etc/snapserver.conf > /tmp/snapserver.conf

# Create fifo
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

# Play start sound
if [ "$SNAPSERVER_START_SOUND_ENABLED" = true ] && echo "$SNAPSERVER_SOURCE" | grep -Eq '^pipe://'; then
	(
		sleep 3
		echo Playing start sound
		FIFO="$(echo "$SNAPSERVER_SOURCE" | grep -Em1 '^pipe://' | sed -E 's!^pipe://!!; s!\?.*$!!')" &&
		sox -V -r 48000 -n -b 16 -c 2 /tmp/start.wav synth 3 sin 0+15000 sin 1000+80000 vol -10db remix 1,2 channels 2 &&
		cat /tmp/start.wav > "$FIFO"
	) &
fi

set -x
exec snapserver -c /tmp/snapserver.conf ${SNAPSERVER_OPTS:-} "$@"
