#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# ntfy add-on initialization
# Generates server.yml, handles Let's Encrypt certificate acquisition
# ==============================================================================

declare domain
declare ssl
declare certfile
declare keyfile
declare letsencrypt
declare letsencrypt_email
declare auth_default_access
declare upstream_base_url
declare log_level

# ---------------------------------------------------------------------------
# Read configuration from Home Assistant add-on options
# ---------------------------------------------------------------------------
domain=$(bashio::config 'domain')
ssl=$(bashio::config 'ssl')
certfile=$(bashio::config 'certfile')
keyfile=$(bashio::config 'keyfile')
letsencrypt=$(bashio::config 'letsencrypt')
letsencrypt_email=$(bashio::config 'letsencrypt_email')
auth_default_access=$(bashio::config 'auth_default_access')
upstream_base_url=$(bashio::config 'upstream_base_url')
log_level=$(bashio::config 'log_level')

# ---------------------------------------------------------------------------
# Create persistent data directories
# ---------------------------------------------------------------------------
mkdir -p /data/ntfy
mkdir -p /ssl/letsencrypt

# ---------------------------------------------------------------------------
# Let's Encrypt certificate acquisition
# ---------------------------------------------------------------------------
if bashio::var.true "${letsencrypt}"; then
    if bashio::var.is_empty "${domain}"; then
        bashio::log.fatal "Let's Encrypt requires a domain to be configured"
        bashio::exit.nok
    fi

    if bashio::var.is_empty "${letsencrypt_email}"; then
        bashio::log.fatal "Let's Encrypt requires an email address"
        bashio::exit.nok
    fi

    LE_CERT_DIR="/etc/letsencrypt/live/${domain}"

    if [ ! -f "${LE_CERT_DIR}/fullchain.pem" ]; then
        bashio::log.info "Requesting Let's Encrypt certificate for ${domain}..."

        certbot certonly \
            --standalone \
            --preferred-challenges http \
            --http-01-port 80 \
            --domain "${domain}" \
            --email "${letsencrypt_email}" \
            --agree-tos \
            --non-interactive \
            --keep-until-expiring

        if [ $? -ne 0 ]; then
            bashio::log.error "Failed to obtain Let's Encrypt certificate"
            bashio::log.error "Ensure port 80 is forwarded and the domain resolves to this server"
        else
            bashio::log.info "Let's Encrypt certificate obtained successfully"
        fi
    else
        bashio::log.info "Let's Encrypt certificate already exists for ${domain}"
    fi

    # Point to Let's Encrypt cert paths
    CERT_FILE="${LE_CERT_DIR}/fullchain.pem"
    KEY_FILE="${LE_CERT_DIR}/privkey.pem"

elif bashio::var.true "${ssl}"; then
    bashio::log.info "Using manually provided SSL certificates from /ssl/"
    CERT_FILE="/ssl/${certfile}"
    KEY_FILE="/ssl/${keyfile}"

    if [ ! -f "${CERT_FILE}" ]; then
        bashio::log.fatal "SSL certificate not found: ${CERT_FILE}"
        bashio::exit.nok
    fi
    if [ ! -f "${KEY_FILE}" ]; then
        bashio::log.fatal "SSL private key not found: ${KEY_FILE}"
        bashio::exit.nok
    fi
else
    CERT_FILE=""
    KEY_FILE=""
fi

# ---------------------------------------------------------------------------
# Generate /etc/ntfy/server.yml
# ---------------------------------------------------------------------------
bashio::log.info "Generating ntfy server configuration..."

{
    # Base URL (if domain is configured)
    if bashio::var.has_value "${domain}"; then
        if [ -n "${CERT_FILE}" ]; then
            echo "base-url: \"https://${domain}\""
        else
            echo "base-url: \"http://${domain}\""
        fi
    fi

    # HTTP listener for ingress (always enabled)
    echo "listen-http: \":2586\""

    # HTTPS listener (if SSL is configured)
    if [ -n "${CERT_FILE}" ] && [ -n "${KEY_FILE}" ]; then
        echo "listen-https: \":443\""
        echo "cert-file: \"${CERT_FILE}\""
        echo "key-file: \"${KEY_FILE}\""
    fi

    # Behind-proxy for Home Assistant ingress
    echo "behind-proxy: true"

    # Persistent storage
    echo "cache-file: \"/data/ntfy/cache.db\""
    echo "cache-duration: \"12h\""
    echo "auth-file: \"/data/ntfy/user.db\""
    echo "attachment-cache-dir: \"/data/ntfy/attachments\""

    # Auth
    echo "auth-default-access: \"${auth_default_access}\""

    # Upstream (for iOS push notifications)
    if bashio::var.has_value "${upstream_base_url}"; then
        echo "upstream-base-url: \"${upstream_base_url}\""
    fi

    # Logging
    echo "log-level: \"${log_level}\""
    echo "log-format: \"text\""

    # Keepalive
    echo "keepalive-interval: \"45s\""

} > /etc/ntfy/server.yml

bashio::log.info "ntfy configuration written to /etc/ntfy/server.yml"

# Log summary
bashio::log.info "---"
bashio::log.info "ntfy ingress (HTTP) listening on port 2586"
if [ -n "${CERT_FILE}" ]; then
    bashio::log.info "ntfy external (HTTPS) listening on port 443"
fi
if bashio::var.has_value "${domain}"; then
    bashio::log.info "Domain: ${domain}"
fi
bashio::log.info "Auth default access: ${auth_default_access}"
bashio::log.info "Log level: ${log_level}"
bashio::log.info "---"
