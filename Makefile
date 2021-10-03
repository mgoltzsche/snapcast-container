PLATFORM ?= linux/amd64

SNAPCAST_CLIENT_BUILD_OPTS = -t mgoltzsche/snapcast/snapclient:dev
SNAPCAST_SERVER_BUILD_OPTS = -t mgoltzsche/snapcast/snapserver:dev

BUILDX_BUILDER ?= snapcast-builder
BUILDX_OUTPUT ?= type=docker
BUILDX_OPTS ?= --builder=$(BUILDX_BUILDER) --output=$(BUILDX_OUTPUT) --platform=$(PLATFORM)
DOCKER ?= docker

all: client server

client: create-builder
	$(DOCKER) buildx build $(BUILDX_OPTS) --force-rm $(SNAPCAST_CLIENT_BUILD_OPTS) --target client .

server: create-builder
	$(DOCKER) buildx build $(BUILDX_OPTS) --force-rm $(SNAPCAST_SERVER_BUILD_OPTS) .

create-builder:
	$(DOCKER) buildx inspect $(BUILDX_BUILDER) >/dev/null 2<&1 || $(DOCKER) buildx create --name=$(BUILDX_BUILDER) >/dev/null

delete-builder:
	$(DOCKER) buildx rm $(BUILDX_BUILDER)
