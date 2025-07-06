#!/usr/bin/with-contenv bashio

# Create Vector configuration directory if it doesn't exist
mkdir -p /config/vector

# Ensure permissions are correct
chmod 755 /etc/s6-overlay/s6-rc.d/vector/run

# Get user-provided Vector configuration
if bashio::config.has_value 'vector_config'; then
    bashio::log.info "Using user-provided Vector configuration..."
    # Write the user-provided configuration to the vector.yaml file
    bashio::config.get 'vector_config' > /config/vector/vector.yaml
else
    # Create default configuration if it doesn't exist and no user config is provided
    if [ ! -f /config/vector/vector.yaml ]; then
        bashio::log.info "Creating default Vector configuration..."
        cp /etc/vector/vector.yaml.template /config/vector/vector.yaml
    fi
fi

# Log configuration
bashio::log.info "Vector configuration is stored in /config/vector/vector.yaml"
bashio::log.info "Vector API will be available at http://[HOST]:8686"
