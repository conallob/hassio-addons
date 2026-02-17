ARG NTFY_VERSION=2.11.0

# Stage 1: Get ntfy binary from official multi-platform image
FROM binwiederhier/ntfy:v${NTFY_VERSION} AS ntfy-source

# Stage 2: Final image on multi-platform Debian base
FROM debian:bookworm-slim

ARG TARGETARCH
ARG S6_OVERLAY_VERSION=3.1.6.2
ARG BASHIO_VERSION=0.16.2

ENV DEBIAN_FRONTEND=noninteractive
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

# Labels
LABEL \
    io.hass.name="ntfy" \
    io.hass.description="Self-hosted push notification server with Let's Encrypt SSL" \
    io.hass.type="addon" \
    maintainer="Conall O'Brien <conall@conall.net>"

# Install base dependencies + certbot
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        certbot \
        curl \
        jq \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install s6-overlay (architecture-aware)
RUN S6_ARCH=$(case ${TARGETARCH} in "amd64") echo "x86_64";; "arm64") echo "aarch64";; *) echo "${TARGETARCH}";; esac) \
    && curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" | tar -C / -Jxpf - \
    && curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" | tar -C / -Jxpf -

# Install bashio (Home Assistant shell library)
RUN curl -fsSL "https://github.com/hassio-addons/bashio/archive/refs/tags/v${BASHIO_VERSION}.tar.gz" | tar -xz \
    && mv "bashio-${BASHIO_VERSION}/lib" /usr/lib/bashio \
    && ln -s /usr/lib/bashio/bashio /usr/bin/bashio \
    && rm -rf "bashio-${BASHIO_VERSION}"

# Copy ntfy binary from official image (correct arch selected automatically)
COPY --from=ntfy-source /usr/bin/ntfy /usr/bin/ntfy

# Copy add-on rootfs
COPY rootfs /

# Create required directories and set permissions
RUN mkdir -p /var/cache/ntfy /var/lib/ntfy /etc/ntfy /data /config \
    && chmod a+x /etc/cont-init.d/*.sh \
    && chmod a+x /etc/s6-overlay/s6-rc.d/*/run

# Expose ports: 2586=ingress HTTP, 443=external HTTPS, 80=HTTP/ACME
EXPOSE 2586 443 80

ENTRYPOINT ["/init"]
