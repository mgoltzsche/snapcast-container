FROM alpine:3.22 AS alpine

# Build librespot
FROM rust:1.89-alpine3.22 AS librespot
RUN apk add --update --no-cache git musl-dev
ARG LIBRESPOT_VERSION=v0.7.1
RUN git clone -c 'advice.detachedHead=false' --branch=$LIBRESPOT_VERSION --depth=1 https://github.com/librespot-org/librespot
WORKDIR /librespot
ENV RUSTFLAGS='-C link-arg=-s'
RUN cargo build --release --no-default-features --features=with-libmdns,rustls-tls-native-roots

# Install build dependencies
FROM alpine AS builddeps
RUN apk add --update --no-cache git cmake make bash gcc g++ musl-dev avahi-dev openssl-dev alsa-lib-dev pulseaudio-dev libvorbis-dev opus-dev flac-dev soxr-dev boost-dev expat-dev
ARG SNAPCAST_VERSION=v0.32.3
RUN git clone -c 'advice.detachedHead=false' --depth=1 --branch=${SNAPCAST_VERSION} https://github.com/badaix/snapcast.git /snapcast
WORKDIR /snapcast
RUN cmake -DBUILD_WITH_PULSE=ON .

# Build server
FROM builddeps AS serverbuild
WORKDIR /snapcast/server
RUN make

# Build client
FROM builddeps AS clientbuild
WORKDIR /snapcast/client
RUN make

# Download snapweb
FROM alpine AS snapweb
ARG SNAPWEB_VERSION=v0.9.1
RUN apk add --update --no-cache unzip
RUN set -ex; \
	wget -O /tmp/snapweb.zip https://github.com/badaix/snapweb/releases/download/$SNAPWEB_VERSION/snapweb.zip; \
	unzip /tmp/snapweb.zip -d /snapweb

FROM alpine AS snapcastdeps
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
COPY --from=librespot /librespot/target/release/librespot /usr/local/bin/librespot.bin
COPY librespot-wrapper.sh /usr/local/bin/librespot
COPY --from=serverbuild /snapcast/bin/snapserver /usr/local/bin/snapserver
COPY --from=snapweb /snapweb /usr/share/snapserver/snapweb
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
	SNAPSERVER_SOURCE=tcp://0.0.0.0:1709?name=TCP \
	SNAPSERVER_SOURCE_CREATE_FIFO= \
	SNAPSERVER_SOURCE_LIBRESPOT_ENABLED=true \
	SNAPSERVER_SOUND_TEST=false \
	SNAPSERVER_START_SOUND_ENABLED=true \
	SNAPSERVER_SAMPLEFORMAT=48000:16:2 \
	SNAPSERVER_CODEC=flac \
	SNAPSERVER_CHUNK_MS=20 \
	SNAPSERVER_BUFFER_MS=3000 \
	SNAPSERVER_INITIAL_VOLUME=30 \
	SNAPSERVER_ADDITIONAL_CONFIG=
RUN adduser -D -H -u 4242 snapserver
RUN set -ex; \
	mkdir /data; \
	chown snapserver:snapserver /data; \
	chmod 2770 /data; \
	mkdir -p /home/snapserver/.config/snapserver /var/lib/snapserver; \
	chown -R snapserver /home/snapserver/.config /var/lib/snapserver
USER snapserver:snapserver
COPY snapserver.sh /
RUN /snapserver.sh --version && rm -rf /tmp/snapserver.conf
ENTRYPOINT [ "/snapserver.sh" ]
