#!/bin/sh

set -eu

waitForSnapserver() {
	while ! timeout 3s nc -z "$SNAPCLIENT_HOST" "$SNAPCLIENT_PORT" 2>/dev/null; do
		echo "Waiting for Snapserver at $SNAPCLIENT_HOST:$SNAPCLIENT_PORT to become available" >&2
		sleep 3
	done
}

findPulseaudioUser() {
	for uid in `ls /host/run/user 2>/dev/null || true`; do
		if [ -S "/host/run/user/${uid}/pulse/native" ]; then
			echo $uid
			return 0
		fi
	done
}

if [ "${SNAPCLIENT_HOSTID:-}" ]; then
	SNAPCLIENT_OPTS="${SNAPCLIENT_OPTS:-} --hostID $SNAPCLIENT_HOSTID"
fi

if [ "${SNAPCLIENT_INSTANCE:-}" ]; then
	SNAPCLIENT_OPTS="${SNAPCLIENT_OPTS:-} --instance $SNAPCLIENT_INSTANCE"
fi

if [ "${SNAPCLIENT_SOUNDCARD:-}" ]; then
	SNAPCLIENT_OPTS="${SNAPCLIENT_OPTS:-} --soundcard $SNAPCLIENT_SOUNDCARD"
fi

if [ "${SNAPCLIENT_SAMPLEFORMAT:-}" ]; then
	SNAPCLIENT_OPTS="${SNAPCLIENT_OPTS:-} --sampleformat $SNAPCLIENT_SAMPLEFORMAT"
fi

if [ "${SNAPCLIENT_LATENCY:-}" ]; then
	SNAPCLIENT_OPTS="${SNAPCLIENT_OPTS:-} --latency $SNAPCLIENT_LATENCY"
fi

if [ "${SNAPCLIENT_PLAYER:-}" ]; then
	SNAPCLIENT_OPTS="${SNAPCLIENT_OPTS:-} --player $SNAPCLIENT_PLAYER"
else
	PULSEAUDIO_USER="`findPulseaudioUser`"
	if [ "$PULSEAUDIO_USER" ]; then
		if [ ! "$PULSEAUDIO_USER" = "`id -u`" ]; then
			exec su-exec $PULSEAUDIO_USER:$PULSEAUDIO_USER "$0" "$@"
			exit $?
		fi
		PULSEAUDIO_UNIX_SOCKET="/host/run/user/${PULSEAUDIO_USER}/pulse/native"
		SNAPCLIENT_OPTS="${SNAPCLIENT_OPTS:-} --player pulse:server=unix:$PULSEAUDIO_UNIX_SOCKET"
	elif amixer | grep -q "Simple mixer control 'Digital'"; then
		# Default to hardware mixer if available
		: ${SNAPCLIENT_MIXER:=hardware:Digital}
	fi
fi

if [ "${SNAPCLIENT_MIXER:-}" ]; then
	SNAPCLIENT_OPTS="${SNAPCLIENT_OPTS:-} --mixer $SNAPCLIENT_MIXER"
fi

if [ ! "${SNAPCLIENT_SERVER_URL:-}" ] && [ "${SNAPCLIENT_HOST:-}" ]; then
	: ${SNAPCLIENT_PORT:=1704}
	waitForSnapserver
	SNAPCLIENT_SERVER_URL="tcp://$SNAPCLIENT_HOST:$SNAPCLIENT_PORT"
fi

set -x
exec snapclient --logsink=stdout ${SNAPCLIENT_OPTS:-} "$@" ${SNAPCLIENT_SERVER_URL:-}
