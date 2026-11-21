ARG BUILD_FROM

# Stage 1: Pull the static Cloudprober binary from the official image
FROM cloudprober/cloudprober:v0.14.7 AS cloudprober-source

# Stage 2: Build the add-on image on the HA Debian base (includes s6-overlay)
FROM ${BUILD_FROM}

# Labels
LABEL \
    io.hass.name="Cloudprober" \
    io.hass.description="Synthetic probing for Home Assistant and your network" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    maintainer="Conall O'Brien <conall@conall.net>"

# Copy the static Cloudprober binary from the official image
COPY --from=cloudprober-source /cloudprober /usr/bin/cloudprober

# Copy add-on rootfs (s6 services, init scripts)
COPY rootfs /

# Create required directories
RUN mkdir -p /data/cloudprober

# Set script permissions
RUN chmod a+x /etc/cont-init.d/*.sh \
    && chmod a+x /etc/s6-overlay/s6-rc.d/*/run

# Cloudprober HTTP status page / Prometheus metrics
EXPOSE 9313
