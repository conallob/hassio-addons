ARG BUILD_FROM
ARG NTFY_VERSION=2.11.0

# Stage 1: Get ntfy binary from official image
FROM binwiederhier/ntfy:v${NTFY_VERSION} AS ntfy-source

# Stage 2: Build the add-on image on the HA Debian base
FROM ${BUILD_FROM}

# Labels
LABEL \
    io.hass.name="ntfy" \
    io.hass.description="Self-hosted push notification server with Let's Encrypt SSL" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    maintainer="Conall O'Brien <conall@conall.net>"

# Install certbot and dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        certbot \
        ca-certificates \
        wget \
    && rm -rf /var/lib/apt/lists/*

# Copy ntfy binary from official image
COPY --from=ntfy-source /usr/bin/ntfy /usr/bin/ntfy

# Copy add-on rootfs
COPY rootfs /

# Create required directories
RUN mkdir -p \
    /var/cache/ntfy \
    /var/lib/ntfy \
    /etc/ntfy \
    /data \
    /config

# Set script permissions
RUN chmod a+x /etc/cont-init.d/*.sh \
    && chmod a+x /etc/s6-overlay/s6-rc.d/*/run

# Expose ports: 2586=ingress HTTP, 443=external HTTPS, 80=HTTP/ACME
EXPOSE 2586 443 80
