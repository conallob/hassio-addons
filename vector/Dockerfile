ARG BUILD_FROM
ARG VECTOR_VERSION=0.48.0

# Stage 1: Pull the Vector binary from the official image
FROM timberio/vector:${VECTOR_VERSION}-debian AS vector-source

# Stage 2: Build the add-on image on the HA Debian base (includes s6-overlay)
FROM ${BUILD_FROM}

ARG VECTOR_VERSION

# Labels
LABEL \
    io.hass.name="Vector" \
    io.hass.description="High-performance observability data pipeline" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    maintainer="Conall O'Brien <conall@conall.net>"

# Install jq for parsing Home Assistant options
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*

# Copy Vector binary from the official image
COPY --from=vector-source /usr/bin/vector /usr/bin/vector

# Copy add-on rootfs (s6 services, init scripts, config template)
COPY rootfs /

# Create required directories
RUN mkdir -p /config/vector /data /etc/vector

# Set script permissions
RUN chmod a+x /etc/cont-init.d/*.sh \
    && chmod a+x /etc/s6-overlay/s6-rc.d/*/run

EXPOSE 8686
