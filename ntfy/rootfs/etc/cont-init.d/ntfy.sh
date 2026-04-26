#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# ntfy add-on initialization
# Generates /etc/ntfy/server.yml from add-on options.
#
# SSL is handled externally by the Home Assistant Let's Encrypt add-on, which
# writes certificates to /ssl/. This add-on simply reads them from there.
# ==============================================================================

declare domain
declare ssl
declare certfile
declare keyfile
declare auth_default_access
declare upstream_base_url
declare log_level
declare ingress_url

# ---------------------------------------------------------------------------
# Read configuration from Home Assistant add-on options
# ---------------------------------------------------------------------------
domain=$(bashio::config 'domain')
ssl=$(bashio::config 'ssl')
certfile=$(bashio::config 'certfile')
keyfile=$(bashio::config 'keyfile')
auth_default_access=$(bashio::config 'auth_default_access')
upstream_base_url=$(bashio::config 'upstream_base_url')
log_level=$(bashio::config 'log_level')

# Retrieve the ingress URL so ntfy generates correct asset/redirect URLs
# when accessed through the Home Assistant ingress proxy.
ingress_url=$(bashio::addon.ingress_url)

# ---------------------------------------------------------------------------
# Create persistent data directories
# ---------------------------------------------------------------------------
mkdir -p /data/ntfy/attachments

# ---------------------------------------------------------------------------
# Resolve SSL certificate paths (from /ssl/, managed by HA Let's Encrypt add-on)
# ---------------------------------------------------------------------------
CERT_FILE=""
KEY_FILE=""

if bashio::var.true "${ssl}"; then
    CERT_FILE="/ssl/${certfile}"
    KEY_FILE="/ssl/${keyfile}"

    if [ ! -f "${CERT_FILE}" ]; then
        bashio::log.fatal "SSL certificate not found: ${CERT_FILE}"
        bashio::log.fatal "The HA Let's Encrypt add-on must be configured to copy the certificate to /ssl/."
        bashio::log.fatal "In the Let's Encrypt add-on configuration, set:"
        bashio::log.fatal "  certfile: ${certfile}"
        bashio::log.fatal "  keyfile: ${keyfile}"
        bashio::log.fatal "Then run the Let's Encrypt add-on and restart ntfy."
        bashio::exit.nok
    fi
    if [ ! -f "${KEY_FILE}" ]; then
        bashio::log.fatal "SSL private key not found: ${KEY_FILE}"
        bashio::log.fatal "The HA Let's Encrypt add-on must be configured to copy the key to /ssl/."
        bashio::log.fatal "In the Let's Encrypt add-on configuration, set:"
        bashio::log.fatal "  certfile: ${certfile}"
        bashio::log.fatal "  keyfile: ${keyfile}"
        bashio::log.fatal "Then run the Let's Encrypt add-on and restart ntfy."
        bashio::exit.nok
    fi

    bashio::log.info "Using SSL certificates from /ssl/ (${certfile} / ${keyfile})"
fi

# ---------------------------------------------------------------------------
# Generate /etc/ntfy/server.yml
# ---------------------------------------------------------------------------
bashio::log.info "Generating ntfy server configuration..."

{
    # base-url drives web UI asset paths and self-links.
    # Priority: explicit domain (external access) > HA ingress URL (sidebar).
    # Without a correct base-url, assets are served from "/" which the HA
    # ingress proxy cannot reach.
    if bashio::var.has_value "${domain}"; then
        if [ -n "${CERT_FILE}" ]; then
            echo "base-url: \"https://${domain}\""
        else
            echo "base-url: \"http://${domain}\""
        fi
    elif bashio::var.has_value "${ingress_url}"; then
        echo "base-url: \"${ingress_url%/}\""
    fi

    # HTTP listener for ingress (always enabled)
    echo "listen-http: \":2586\""

    # HTTPS listener (only when SSL certificates are present)
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

    # Upstream relay (for iOS push notifications via ntfy.sh)
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

# Summary
bashio::log.info "---"
bashio::log.info "ntfy ingress (HTTP) listening on port 2586"
if [ -n "${CERT_FILE}" ]; then
    bashio::log.info "ntfy external (HTTPS) listening on port 443"
fi
if bashio::var.has_value "${domain}"; then
    bashio::log.info "Domain: ${domain}"
elif bashio::var.has_value "${ingress_url}"; then
    bashio::log.info "Ingress base-url: ${ingress_url}"
fi
bashio::log.info "Auth default access: ${auth_default_access}"
bashio::log.info "Log level: ${log_level}"
bashio::log.info "---"
