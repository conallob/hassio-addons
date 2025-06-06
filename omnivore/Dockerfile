ARG BUILD_FROM
FROM $BUILD_FROM

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Setup base system
RUN apk add --no-cache \
    nodejs \
    npm \
    git \
    curl \
    redis \
    postgresql-client

# Set working directory
WORKDIR /app

# Clone Omnivore repository
RUN git clone --depth=1 https://github.com/omnivore-app/omnivore.git /app

# Copy data for add-on
COPY rootfs /

# Set permissions
RUN chmod a+x /etc/services.d/*/run \
    && chmod a+x /etc/cont-init.d/*.sh

# Build and prepare application
RUN mkdir -p /data/omnivore

# Labels
LABEL \
    io.hass.name="Omnivore" \
    io.hass.description="Omnivore is a complete, open source read-it-later solution for people who like reading" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    maintainer="Conall O'Brien <conall@conall.net>"

# Entrypoint
ENTRYPOINT ["/init"]
