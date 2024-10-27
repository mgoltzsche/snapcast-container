FROM alpine:3.19 AS alpine

FROM alpine AS builddeps
RUN apk add --update --no-cache git cmake make bash gcc g++ musl-dev avahi-dev alsa-lib-dev pulseaudio-dev libvorbis-dev opus-dev flac-dev soxr-dev boost-dev expat-dev
ARG SNAPCAST_VERSION=v0.29.0
RUN git clone -c 'advice.detachedHead=false' --depth=1 --branch=${SNAPCAST_VERSION} https://github.com/badaix/snapcast.git /snapcast
WORKDIR /snapcast
RUN cmake .

# Build server
FROM builddeps AS serverbuild
WORKDIR /snapcast/server
RUN make

# Build client
FROM builddeps AS clientbuild
WORKDIR /snapcast/client
RUN make

# Build snapweb
FROM node:22.2-alpine AS snapweb
RUN apk add --update --no-cache git
# TODO: use pre-built assets once patch is released: https://github.com/badaix/snapweb/pull/84
# snapweb v0.7.0 + base URL patch
ARG SNAPWEB_VERSION=ce7be22a186728f58ae257b4a88072f7c1118185
RUN set -ex; \
	git clone -c 'advice.detachedHead=false' https://github.com/mgoltzsche/snapweb.git /snapweb; \
	cd /snapweb; \
	git checkout $SNAPWEB_VERSION
#RUN apk add --update --no-cache unzip
#RUN set -ex; \
#	wget -O /tmp/snapweb.zip https://github.com/badaix/snapweb/releases/download/$SNAPWEB_VERSION/snapweb.zip; \
#	unzip /tmp/snapweb.zip -d /snapweb
WORKDIR /snapweb
RUN set -ex; \
	npm ci; \
	npm run build

FROM alpine:3.19 AS snapcastdeps
RUN apk add --update --no-cache avahi alsa-lib libstdc++ libgcc

# Create final client image
FROM snapcastdeps AS client
RUN apk add --update --no-cache su-exec pulseaudio-utils alsa-utils
COPY --from=clientbuild /snapcast/bin/snapclient /usr/local/bin/snapclient
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
COPY --from=serverbuild /snapcast/bin/snapserver /usr/local/bin/snapserver
COPY --from=snapweb /snapweb/dist /usr/share/snapserver/snapweb
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
	SNAPSERVER_BUFFER_MS=700 \
	SNAPSERVER_INITIAL_VOLUME=30
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
