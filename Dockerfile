# syntax=docker/dockerfile:1

# Crystal Palace exposed through its JSON-over-HTTP sidecar API
#
# Upstream: https://tradecraftgarden.org/crystalpalace.html

ARG JAVA_VERSION=11
ARG CP_VERSION=20261029

# ---------------------------------------------------------------------------
# Build stage
# ---------------------------------------------------------------------------
FROM eclipse-temurin:${JAVA_VERSION}-jdk-jammy AS build

# Update CP_VERSION and CP_SHA256 together when moving to a new release.
# Set CP_SHA256 to an empty string to skip verification. 
# CP_SRC_URL can override the download location
ARG CP_VERSION
ARG CP_SHA256=67e7f8754a1f60549b25c3de8079aa3b2e946d179c111af6418f74dc213cd694
ARG CP_SRC_URL=

# hadolint ignore=DL3008
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ant \
      ca-certificates \
      curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/crystalpalace

RUN url="${CP_SRC_URL:-https://tradecraftgarden.org/download/cpsrc${CP_VERSION}.tgz}" \
 && curl -fsSL --retry 3 --retry-delay 2 -o /tmp/cpsrc.tgz "$url" \
 && if [ -n "$CP_SHA256" ]; then \
        printf '%s  %s\n' "$CP_SHA256" /tmp/cpsrc.tgz > /tmp/cpsrc.sha256 \
        && sha256sum -c /tmp/cpsrc.sha256; \
    fi \
 && tar -xzf /tmp/cpsrc.tgz --strip-components=1 \
 && rm -f /tmp/cpsrc.tgz /tmp/cpsrc.sha256

# build.xml produces build/crystalpalace.jar
RUN ant

# ---------------------------------------------------------------------------
# Runtime stage
# ---------------------------------------------------------------------------
FROM eclipse-temurin:${JAVA_VERSION}-jre-jammy

ARG CP_VERSION

LABEL org.opencontainers.image.title="Crystal Palace sidecar" \
      org.opencontainers.image.description="Crystal Palace exposed over its JSON-over-HTTP sidecar API" \
      org.opencontainers.image.version="${CP_VERSION}" \
      org.opencontainers.image.url="https://tradecraftgarden.org/crystalpalace.html" \
      org.opencontainers.image.licenses="BSD-3-Clause"

# hadolint ignore=DL3008
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends socat \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --uid 1000 --shell /bin/bash cpl

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    CPL_HOME=/opt/crystalpalace \
    CPL_PORT=60060 \
    CPL_INTERNAL_PORT=60061 \
    CPL_BIND=0.0.0.0

COPY --from=build /usr/src/crystalpalace/build/crystalpalace.jar /opt/crystalpalace/crystalpalace.jar
COPY --from=build /usr/src/crystalpalace/LICENSE /opt/crystalpalace/LICENSE
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh \
 && mkdir -p /work \
 && chown -R cpl:cpl /opt/crystalpalace /work

USER cpl
WORKDIR /work

# The sidecar API listens on 60060 inside the container
EXPOSE 60060

# cpl itself binds 127.0.0.1:CPL_INTERNAL_PORT, so probe that directly
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD socat -u /dev/null TCP:127.0.0.1:${CPL_INTERNAL_PORT} || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
