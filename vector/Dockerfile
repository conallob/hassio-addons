ARG BUILD_FROM
FROM timberio/vector:0.48.0-debian

# Labels
LABEL \
    io.hass.name="Vector" \
    io.hass.description="High-performance observability data pipeline" \
    io.hass.type="addon" \
    io.hass.version="0.48.0" \
    maintainer="Conall O'Brien <conall@conall.net>"

# Install jq for parsing Home Assistant options
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*

# Copy addon files
COPY rootfs /

# Create required directories
RUN mkdir -p /config/vector /data

# Make entrypoint executable
RUN chmod +x /run.sh

EXPOSE 8686

ENTRYPOINT ["/run.sh"]
