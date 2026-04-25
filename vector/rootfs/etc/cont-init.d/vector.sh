#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Vector add-on initialization
# Generates vector.yaml from add-on options before the service starts
# ==============================================================================

declare log_level
declare api_enabled
declare vector_config

VECTOR_CONFIG_DIR="/config/vector"
VECTOR_CONFIG_PATH="${VECTOR_CONFIG_DIR}/vector.yaml"

mkdir -p "${VECTOR_CONFIG_DIR}"

# ---------------------------------------------------------------------------
# Read configuration from Home Assistant add-on options
# ---------------------------------------------------------------------------
log_level=$(bashio::config 'log_level')
api_enabled=$(bashio::config 'api_enabled')
vector_config=$(bashio::config 'vector_config')

# ---------------------------------------------------------------------------
# Map Home Assistant log levels to Vector log levels
# ---------------------------------------------------------------------------
case "${log_level}" in
    trace)          VECTOR_LOG="trace" ;;
    debug)          VECTOR_LOG="debug" ;;
    info|notice)    VECTOR_LOG="info"  ;;
    warning)        VECTOR_LOG="warn"  ;;
    error|fatal)    VECTOR_LOG="error" ;;
    *)              VECTOR_LOG="info"  ;;
esac

# Export so the s6 service run script can inherit it
printf '%s' "${VECTOR_LOG}" > /var/run/s6/container_environment/VECTOR_LOG

# ---------------------------------------------------------------------------
# Build the Vector configuration file
# ---------------------------------------------------------------------------
{
    # API section — controlled by the api_enabled toggle in the add-on UI
    if bashio::var.true "${api_enabled}"; then
        cat <<'APIBLOCK'
api:
  enabled: true
  address: 0.0.0.0:8686

APIBLOCK
    fi

    # User-supplied pipeline (sources / transforms / sinks)
    if bashio::var.has_value "${vector_config}"; then
        printf '%s\n' "${vector_config}"
    else
        # Fallback to the bundled default template
        cat /etc/vector/vector.yaml.template
    fi
} > "${VECTOR_CONFIG_PATH}"

bashio::log.info "Vector configuration written to ${VECTOR_CONFIG_PATH}"
bashio::log.info "Log level: ${log_level} (VECTOR_LOG=${VECTOR_LOG})"
bashio::log.info "API enabled: ${api_enabled}"
