ARG BUILD_FROM
FROM $BUILD_FROM

# Use the standard Vector image instead of distroless
FROM timberio/vector:0.48.0-debian

# Labels
LABEL \
    io.hass.name="Vector" \
    io.hass.description="High-performance observability data pipeline" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    maintainer="Conall O'Brien <conall@conall.net>"

# Copy data for add-on
COPY rootfs /

# Create required directories
RUN mkdir -p /data /config

# Set permissions
RUN chmod a+x /etc/s6-overlay/s6-rc.d/*/run

# Expose Vector API port
EXPOSE 8686

# Set entrypoint to s6-overlay
ENTRYPOINT ["/init"]
