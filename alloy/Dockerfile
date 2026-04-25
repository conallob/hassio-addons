ARG BUILD_FROM
ARG ALLOY_VERSION=1.8.3

# Stage 1: Pull the Alloy binary from the official image
FROM grafana/alloy:v${ALLOY_VERSION} AS alloy-source

# Stage 2: Build the add-on image on the HA Debian base (includes s6-overlay)
FROM ${BUILD_FROM}

ARG ALLOY_VERSION

# Labels
LABEL \
    io.hass.name="Grafana Alloy" \
    io.hass.description="Grafana Alloy observability collector" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    maintainer="Conall O'Brien <conall@conall.net>"

# Install jq for parsing Home Assistant options
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*

# Copy Alloy binary from the official image
COPY --from=alloy-source /usr/bin/alloy /usr/bin/alloy

# Copy add-on rootfs (s6 services, init scripts, config template)
COPY rootfs /

# Create required directories
RUN mkdir -p /data/alloy /etc/alloy /config/alloy

# Set script permissions
RUN chmod a+x /etc/cont-init.d/*.sh \
    && chmod a+x /etc/s6-overlay/s6-rc.d/*/run

# Alloy HTTP UI / API
EXPOSE 12345
