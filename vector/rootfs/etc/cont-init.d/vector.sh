#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Vector add-on initialization
# Generates /config/vector/vector.yaml from add-on options.
#
# Vector's pipeline (sources, transforms, sinks) is configured directly in
# native Vector YAML via the vector_config option — see
# https://vector.dev/docs/reference/configuration/ for syntax.
#
# The add-on only manages two things on top of that:
#   log_level    — Vector's own log verbosity (VECTOR_LOG env var)
#   api_enabled  — whether to inject the `api:` block Vector needs for the
#                  add-on's ingress panel to work. Do not declare your own
#                  top-level `api:` key in vector_config; use this option
#                  instead.
# ==============================================================================

declare log_level
declare api_enabled
declare vector_config

VECTOR_CONFIG_DIR="/config/vector"
VECTOR_CONFIG_PATH="${VECTOR_CONFIG_DIR}/vector.yaml"

mkdir -p "${VECTOR_CONFIG_DIR}"

# ---------------------------------------------------------------------------
# Read configuration
# ---------------------------------------------------------------------------
log_level=$(bashio::config 'log_level')
api_enabled=$(bashio::config 'api_enabled')
vector_config=$(bashio::config 'vector_config')

# ---------------------------------------------------------------------------
# Map HA log level to Vector log level
# ---------------------------------------------------------------------------
case "${log_level}" in
    trace)          VECTOR_LOG="trace" ;;
    debug)          VECTOR_LOG="debug" ;;
    info|notice)    VECTOR_LOG="info"  ;;
    warning)        VECTOR_LOG="warn"  ;;
    error|fatal)    VECTOR_LOG="error" ;;
    *)              VECTOR_LOG="info"  ;;
esac

printf '%s' "${VECTOR_LOG}" > /var/run/s6/container_environment/VECTOR_LOG

# ---------------------------------------------------------------------------
# A pipeline is required — there's nothing sensible to fall back to
# ---------------------------------------------------------------------------
if ! bashio::var.has_value "${vector_config}"; then
    bashio::log.fatal "vector_config is empty. Provide a Vector pipeline (sources/transforms/sinks) in the add-on's configuration."
    bashio::exit.nok
fi

# ---------------------------------------------------------------------------
# Write the final config: our api: block (if enabled) + the user's pipeline
# ---------------------------------------------------------------------------
{
    if bashio::var.true "${api_enabled}"; then
        cat <<'APIBLOCK'
api:
  enabled: true
  address: 0.0.0.0:8686

APIBLOCK
    fi

    printf '%s\n' "${vector_config}"
} > "${VECTOR_CONFIG_PATH}"

bashio::log.info "Vector configuration written to ${VECTOR_CONFIG_PATH}"
bashio::log.info "Log level: ${log_level} (VECTOR_LOG=${VECTOR_LOG})"
bashio::log.info "API enabled: ${api_enabled}"
