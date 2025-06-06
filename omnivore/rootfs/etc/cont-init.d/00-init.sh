#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Omnivore
# Configures Omnivore before running
# ==============================================================================

# Create data directory if it doesn't exist
mkdir -p /data/omnivore

# Create environment file
ENV_FILE="/data/omnivore/.env"

# Set default environment variables if not already set
if [ ! -f "${ENV_FILE}" ]; then
    bashio::log.info "Creating default environment file..."
    
    # Get PostgreSQL credentials from Home Assistant
    if bashio::services.available "postgres"; then
        bashio::log.info "PostgreSQL service detected, using Home Assistant database"
        POSTGRES_HOST=$(bashio::services "postgres" "host")
        POSTGRES_PORT=$(bashio::services "postgres" "port")
        POSTGRES_USER=$(bashio::services "postgres" "username")
        POSTGRES_PASSWORD=$(bashio::services "postgres" "password")
        POSTGRES_DB="omnivore"
    else
        bashio::log.warning "PostgreSQL service not detected, using default values"
        POSTGRES_HOST="localhost"
        POSTGRES_PORT="5432"
        POSTGRES_USER="postgres"
        POSTGRES_PASSWORD="postgres"
        POSTGRES_DB="omnivore"
    fi

    # Create the .env file with default values
    cat > "${ENV_FILE}" << EOF
# Base URLs
BASE_URL=http://localhost:3000
SERVER_BASE_URL=http://localhost:4000
HIGHLIGHTS_BASE_URL=http://localhost:3000
CLIENT_URL=http://localhost:3000
IMAGEPROXY_URL=http://localhost:7070

# Database
POSTGRES_HOST=${POSTGRES_HOST}
POSTGRES_PORT=${POSTGRES_PORT}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}
DATABASE_URL=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}

# Redis
REDIS_URL=redis://localhost:6379

# Storage
AWS_ACCESS_KEY_ID=minio
AWS_SECRET_ACCESS_KEY=miniominio
AWS_REGION=us-east-1
LOCAL_MINIO_URL=http://localhost:1010
GCS_USE_LOCAL_HOST=true

# Auth
AUTH_SECRET=replace_this_with_a_random_string
COOKIE_DOMAIN=localhost

# App settings
NODE_ENV=production
LOG_LEVEL=$(bashio::config 'log_level')
EOF
fi

# Set permissions
chown -R root:root /data/omnivore
chmod -R 755 /data/omnivore

# Copy the environment file to the app directory
cp "${ENV_FILE}" /app/self-hosting/docker-compose/.env

bashio::log.info "Initialization complete"
