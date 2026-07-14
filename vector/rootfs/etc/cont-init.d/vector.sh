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
# The add-on only manages a few things on top of that:
#   log_level       — Vector's own log verbosity (VECTOR_LOG env var)
#   api_enabled     — whether to inject the `api:` block Vector needs for the
#                      add-on's ingress panel to work. Do not declare your own
#                      top-level `api:` key in vector_config; use this option
#                      instead.
#   syslog_enabled  — adds `syslog_tcp`/`syslog_udp` sources listening on the
#                      standard syslog port (514, already mapped) into your
#                      `sources:` block, so you don't have to hand-write them.
#                      Reference those IDs as sink inputs to use them.
# ==============================================================================

declare log_level
declare api_enabled
declare syslog_enabled
declare vector_config

VECTOR_CONFIG_DIR="/config/vector"
VECTOR_CONFIG_PATH="${VECTOR_CONFIG_DIR}/vector.yaml"

mkdir -p "${VECTOR_CONFIG_DIR}"

# ---------------------------------------------------------------------------
# Read configuration
# ---------------------------------------------------------------------------
log_level=$(bashio::config 'log_level')
api_enabled=$(bashio::config 'api_enabled')
syslog_enabled=$(bashio::config 'syslog_enabled')
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
# syslog_enabled: merge syslog_tcp/syslog_udp source entries (port 514) into
# the user's `sources:` block, or add one if they don't have one.
# ---------------------------------------------------------------------------
SYSLOG_SOURCES=$'  syslog_tcp:\n    type: syslog\n    mode: tcp\n    address: "0.0.0.0:514"\n\n  syslog_udp:\n    type: syslog\n    mode: udp\n    address: "0.0.0.0:514"\n'

write_pipeline() {
    if ! bashio::var.true "${syslog_enabled}"; then
        printf '%s\n' "${vector_config}"
        return
    fi

    if printf '%s\n' "${vector_config}" | grep -qE '^sources:[[:space:]]*$'; then
        printf '%s\n' "${vector_config}" | awk -v frag="${SYSLOG_SOURCES}" '
            { print }
            /^sources:[[:space:]]*$/ && !done { print frag; done=1 }
        '
    else
        printf 'sources:\n%s\n' "${SYSLOG_SOURCES}"
        printf '%s\n' "${vector_config}"
    fi
}

# ---------------------------------------------------------------------------
# Write the final config: our api: block (if enabled) + the pipeline
# ---------------------------------------------------------------------------
{
    if bashio::var.true "${api_enabled}"; then
        cat <<'APIBLOCK'
api:
  enabled: true
  address: 0.0.0.0:8686

APIBLOCK
    fi

    write_pipeline
} > "${VECTOR_CONFIG_PATH}"

bashio::log.info "Vector configuration written to ${VECTOR_CONFIG_PATH}"
bashio::log.info "Log level: ${log_level} (VECTOR_LOG=${VECTOR_LOG})"
bashio::log.info "API enabled: ${api_enabled}"
bashio::log.info "Syslog (514/tcp+udp) enabled: ${syslog_enabled}"
