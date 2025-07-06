#!/usr/bin/with-contenv bashio

# Create Vector configuration directory if it doesn't exist
mkdir -p /config/vector

# Ensure permissions are correct
chmod 755 /etc/s6-overlay/s6-rc.d/vector/run

# Create default configuration if it doesn't exist
if [ ! -f /config/vector/vector.yaml ]; then
    bashio::log.info "Creating default Vector configuration..."
    cp /etc/vector/vector.yaml.template /config/vector/vector.yaml
fi

# Log configuration
bashio::log.info "Vector configuration is stored in /config/vector/vector.yaml"
bashio::log.info "Vector API will be available at http://[HOST]:8686"
