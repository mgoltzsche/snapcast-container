#!/bin/sh

set -eu

findPulseaudioUser() {
	for uid in `ls /host/run/user 2>/dev/null || true`; do
		if [ -S "/host/run/user/${uid}/pulse/native" ]; then
			echo $uid
			return 0
		fi
	done
}

if [ "${SNAPCLIENT_HOST:-}" ]; then
	SNAPCLIENT_OPTS="${SNAPCLIENT_OPTS:-} --host $SNAPCLIENT_HOST"
elif [ "${SNAPCLIENT_K8S_NAMESPACE:-}" -a "${SNAPCLIENT_K8S_SERVICE:-}" ]; then
	: ${SNAPCLIENT_K8S_CLUSTER_DOMAIN:=cluster.local}
	SNAPCLIENT_OPTS="${SNAPCLIENT_OPTS:-} --host ${SNAPCLIENT_K8S_SERVICE}.${SNAPCLIENT_K8S_NAMESPACE}.svc.$SNAPCLIENT_K8S_CLUSTER_DOMAIN"
fi

if [ "${SNAPCLIENT_PORT:-}" ]; then
	SNAPCLIENT_OPTS="${SNAPCLIENT_OPTS:-} --port $SNAPCLIENT_PORT"
fi

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
	fi
fi

if [ "${SNAPCLIENT_MIXER:-}" ]; then
	SNAPCLIENT_OPTS="${SNAPCLIENT_OPTS:-} --mixer $SNAPCLIENT_MIXER"
fi

set -x
exec snapclient --logsink=stdout ${SNAPCLIENT_OPTS:-} "$@"
