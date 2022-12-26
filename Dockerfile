FROM alpine:3.17 AS alpine

FROM alpine AS builddeps
RUN apk add --update --no-cache git make bash gcc g++ musl-dev avahi-dev alsa-lib-dev pulseaudio-dev libvorbis-dev opus-dev flac-dev soxr-dev boost-dev expat-dev
ARG SNAPCAST_VERSION=v0.26.0
RUN git clone -c 'advice.detachedHead=false' --depth=1 --branch=${SNAPCAST_VERSION} https://github.com/badaix/snapcast.git /snapcast

# Build server
FROM builddeps AS serverbuild
WORKDIR /snapcast/server
RUN make

# Build client
FROM builddeps AS clientbuild
WORKDIR /snapcast/client
RUN make


FROM alpine:3.17 AS snapcastdeps
RUN apk add --update --no-cache avahi alsa-lib

# Create final client image
FROM snapcastdeps AS client
RUN apk add --update --no-cache pulseaudio-utils su-exec
COPY --from=clientbuild /snapcast/client/snapclient /usr/local/bin/snapclient
RUN set -ex; \
	adduser -D -u 2342 snapclient audio; \
	ln -s /host/etc/asound.conf /etc/asound.conf
USER snapclient:audio
COPY snapclient.sh /
RUN /snapclient.sh --version
COPY asound.conf /etc/asound.conf
ENTRYPOINT [ "/snapclient.sh" ]

# Create final server image
FROM snapcastdeps AS server
RUN apk add --update --no-cache sox soxr libvorbis opus flac gettext
COPY --from=serverbuild /snapcast/server/snapserver /usr/local/bin/snapserver
COPY --from=serverbuild /snapcast/server/etc/index.html /usr/share/snapserver/
COPY --from=serverbuild /snapcast/server/etc/snapweb /usr/share/snapserver/snapweb
COPY snapserver.conf /etc/snapserver.conf
ENV 	SNAPSERVER_HTTP_ENABLED=true \
	SNAPSERVER_HTTP_ADDRESS=0.0.0.0 \
	SNAPSERVER_HTTP_PORT=1780 \
	SNAPSERVER_RPC_ENABLED=true \
	SNAPSERVER_RPC_ADDRESS=0.0.0.0 \
	SNAPSERVER_RPC_PORT=1705 \
	SNAPSERVER_STREAM_ADDRESS=0.0.0.0 \
	SNAPSERVER_STREAM_PORT=1704 \
	SNAPSERVER_DATA_DIR=/var/lib/snapserver \
	SNAPSERVER_SOURCE=pipe:///snapserver/snapfifo?name=default&mode=read \
	SNAPSERVER_SOURCE_CREATE_FIFO= \
	SNAPSERVER_SOUND_TEST=false \
	SNAPSERVER_START_SOUND_ENABLED=true \
	SNAPSERVER_SAMPLEFORMAT=48000:16:2 \
	SNAPSERVER_CODEC=flac \
	SNAPSERVER_CHUNK_MS=20 \
	SNAPSERVER_BUFFER_MS=1000
# TODO: use unprivileged user here - currently that doesn't work well with avahi
RUN adduser -D -H -u 4242 snapserver
RUN set -ex; \
	mkdir /data; \
	chown snapserver:snapserver /data; \
	chmod 2770 /data
USER snapserver:snapserver
COPY snapserver.sh /
RUN /snapserver.sh --version && rm -rf /tmp/snapserver.conf
ENTRYPOINT [ "/snapserver.sh" ]
