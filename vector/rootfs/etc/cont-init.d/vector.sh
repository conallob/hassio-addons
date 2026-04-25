#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Vector add-on initialization
# Generates /config/vector/vector.yaml from structured add-on options.
#
# Sources (any combination):
#   ha_logs          — tail /config/home-assistant.log
#   syslog_tcp_port  — syslog listener on TCP (set to non-zero to enable)
#   syslog_udp_port  — syslog listener on UDP (set to non-zero to enable)
#   vector_source_port — Vector-to-Vector source (set to non-zero to enable)
#
# Transforms:
#   ha_logs_vrl      — VRL applied to HA log events before the sink
#   sink_vrl         — VRL applied to all events before the sink
#
# Sinks:
#   sink_type: console | loki | elasticsearch | http | none
#
# Advanced:
#   vector_config    — raw YAML override; when set, all options above are ignored
# ==============================================================================

declare log_level
declare api_enabled
declare ha_logs
declare ha_logs_vrl
declare syslog_tcp_port
declare syslog_udp_port
declare vector_source_port
declare sink_type
declare loki_url
declare elasticsearch_url
declare http_url
declare sink_auth_username
declare sink_auth_password
declare sink_vrl
declare vector_config

VECTOR_CONFIG_DIR="/config/vector"
VECTOR_CONFIG_PATH="${VECTOR_CONFIG_DIR}/vector.yaml"

mkdir -p "${VECTOR_CONFIG_DIR}"

# ---------------------------------------------------------------------------
# Read configuration
# ---------------------------------------------------------------------------
log_level=$(bashio::config 'log_level')
api_enabled=$(bashio::config 'api_enabled')
ha_logs=$(bashio::config 'ha_logs')
ha_logs_vrl=$(bashio::config 'ha_logs_vrl')
syslog_tcp_port=$(bashio::config 'syslog_tcp_port')
syslog_udp_port=$(bashio::config 'syslog_udp_port')
vector_source_port=$(bashio::config 'vector_source_port')
sink_type=$(bashio::config 'sink_type')
loki_url=$(bashio::config 'loki_url')
elasticsearch_url=$(bashio::config 'elasticsearch_url')
http_url=$(bashio::config 'http_url')
sink_auth_username=$(bashio::config 'sink_auth_username')
sink_auth_password=$(bashio::config 'sink_auth_password')
sink_vrl=$(bashio::config 'sink_vrl')
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
# Raw override: write verbatim and exit early
# ---------------------------------------------------------------------------
if bashio::var.has_value "${vector_config}"; then
    bashio::log.info "Using raw vector_config override"
    printf '%s\n' "${vector_config}" > "${VECTOR_CONFIG_PATH}"
    bashio::log.info "Vector configuration written to ${VECTOR_CONFIG_PATH}"
    bashio::exit.ok
fi

# ---------------------------------------------------------------------------
# Validate: at least one source must be enabled
# ---------------------------------------------------------------------------
has_source=false
bashio::var.true "${ha_logs}" && has_source=true
[ "${syslog_tcp_port:-0}" -gt 0 ] 2>/dev/null && has_source=true
[ "${syslog_udp_port:-0}" -gt 0 ] 2>/dev/null && has_source=true
[ "${vector_source_port:-0}" -gt 0 ] 2>/dev/null && has_source=true

if ! "${has_source}"; then
    bashio::log.fatal "No sources enabled. Enable ha_logs or set a non-zero syslog/vector_source_port."
    bashio::exit.nok
fi

# ---------------------------------------------------------------------------
# Validate sink-specific required options
# ---------------------------------------------------------------------------
case "${sink_type}" in
    loki)
        if ! bashio::var.has_value "${loki_url}"; then
            bashio::log.fatal "sink_type is 'loki' but loki_url is not set"
            bashio::exit.nok
        fi
        ;;
    elasticsearch)
        if ! bashio::var.has_value "${elasticsearch_url}"; then
            bashio::log.fatal "sink_type is 'elasticsearch' but elasticsearch_url is not set"
            bashio::exit.nok
        fi
        ;;
    http)
        if ! bashio::var.has_value "${http_url}"; then
            bashio::log.fatal "sink_type is 'http' but http_url is not set"
            bashio::exit.nok
        fi
        ;;
esac

# ---------------------------------------------------------------------------
# Build all_inputs — list of source component IDs feeding into the sink
# ---------------------------------------------------------------------------
# We accumulate source IDs; transforms wrap the sources inline.
ALL_INPUTS=""

add_input() {
    if [ -z "${ALL_INPUTS}" ]; then
        ALL_INPUTS="$1"
    else
        ALL_INPUTS="${ALL_INPUTS}, $1"
    fi
}

# ---------------------------------------------------------------------------
# Generate config
# ---------------------------------------------------------------------------
{
    # --- API ---
    if bashio::var.true "${api_enabled}"; then
        cat <<'APIBLOCK'
api:
  enabled: true
  address: 0.0.0.0:8686

APIBLOCK
    fi

    # --- Sources ---
    echo "sources:"

    if bashio::var.true "${ha_logs}"; then
        cat <<'HABLOCK'
  ha_logs:
    type: file
    include:
      - /config/home-assistant.log
    read_from: beginning
    line_delimiter: "\n"

HABLOCK
    fi

    if [ "${syslog_tcp_port:-0}" -gt 0 ] 2>/dev/null; then
        cat <<SYSLOG_TCP
  syslog_tcp:
    type: syslog
    mode: tcp
    address: "0.0.0.0:${syslog_tcp_port}"

SYSLOG_TCP
    fi

    if [ "${syslog_udp_port:-0}" -gt 0 ] 2>/dev/null; then
        cat <<SYSLOG_UDP
  syslog_udp:
    type: syslog
    mode: udp
    address: "0.0.0.0:${syslog_udp_port}"

SYSLOG_UDP
    fi

    if [ "${vector_source_port:-0}" -gt 0 ] 2>/dev/null; then
        cat <<VECTOR_SRC
  vector_in:
    type: vector
    address: "0.0.0.0:${vector_source_port}"
    version: "2"

VECTOR_SRC
    fi

    # --- Transforms ---
    echo "transforms:"

    # Per-source VRL transform for HA logs
    if bashio::var.true "${ha_logs}" && bashio::var.has_value "${ha_logs_vrl}"; then
        cat <<HA_VRL_BLOCK
  ha_logs_transform:
    type: remap
    inputs:
      - ha_logs
    source: |
$(printf '%s\n' "${ha_logs_vrl}" | sed 's/^/      /')

HA_VRL_BLOCK
        add_input "ha_logs_transform"
    elif bashio::var.true "${ha_logs}"; then
        add_input "ha_logs"
    fi

    [ "${syslog_tcp_port:-0}" -gt 0 ] 2>/dev/null && add_input "syslog_tcp"
    [ "${syslog_udp_port:-0}" -gt 0 ] 2>/dev/null && add_input "syslog_udp"
    [ "${vector_source_port:-0}" -gt 0 ] 2>/dev/null && add_input "vector_in"

    # Global pre-sink VRL transform (applied to all sources)
    if bashio::var.has_value "${sink_vrl}"; then
        cat <<SINK_VRL_BLOCK
  sink_transform:
    type: remap
    inputs:
      - ${ALL_INPUTS}
    source: |
$(printf '%s\n' "${sink_vrl}" | sed 's/^/      /')

SINK_VRL_BLOCK
        SINK_INPUT="sink_transform"
    else
        SINK_INPUT="${ALL_INPUTS}"
    fi

    # --- Sink ---
    if [ "${sink_type}" = "none" ]; then
        # Blackhole — useful for testing sources/transforms without output
        cat <<BLACKHOLE
sinks:
  blackhole:
    type: blackhole
    inputs:
      - ${SINK_INPUT}

BLACKHOLE
    elif [ "${sink_type}" = "console" ]; then
        cat <<CONSOLE
sinks:
  console:
    type: console
    inputs:
      - ${SINK_INPUT}
    target: stdout
    encoding:
      codec: json

CONSOLE
    elif [ "${sink_type}" = "loki" ]; then
        cat <<LOKI_OPEN
sinks:
  loki:
    type: loki
    inputs:
      - ${SINK_INPUT}
    endpoint: "${loki_url}"
    labels:
      job: home_assistant
      host: "{{ host }}"
    encoding:
      codec: json
LOKI_OPEN

        if bashio::var.has_value "${sink_auth_username}"; then
            cat <<LOKI_AUTH
    auth:
      strategy: basic
      user: "${sink_auth_username}"
      password: "${sink_auth_password}"
LOKI_AUTH
        fi
        echo ""

    elif [ "${sink_type}" = "elasticsearch" ]; then
        cat <<ES_OPEN
sinks:
  elasticsearch:
    type: elasticsearch
    inputs:
      - ${SINK_INPUT}
    endpoints:
      - "${elasticsearch_url}"
ES_OPEN

        if bashio::var.has_value "${sink_auth_username}"; then
            cat <<ES_AUTH
    auth:
      strategy: basic
      user: "${sink_auth_username}"
      password: "${sink_auth_password}"
ES_AUTH
        fi
        echo ""

    elif [ "${sink_type}" = "http" ]; then
        cat <<HTTP_OPEN
sinks:
  http_out:
    type: http
    inputs:
      - ${SINK_INPUT}
    uri: "${http_url}"
    encoding:
      codec: json
    framing:
      method: newline_delimited
HTTP_OPEN

        if bashio::var.has_value "${sink_auth_username}"; then
            cat <<HTTP_AUTH
    auth:
      strategy: basic
      user: "${sink_auth_username}"
      password: "${sink_auth_password}"
HTTP_AUTH
        fi
        echo ""
    fi

} > "${VECTOR_CONFIG_PATH}"

bashio::log.info "Vector configuration written to ${VECTOR_CONFIG_PATH}"
bashio::log.info "---"
bashio::log.info "Sources:"
bashio::var.true "${ha_logs}"                          && bashio::log.info "  ha_logs (tail /config/home-assistant.log)"
[ "${syslog_tcp_port:-0}" -gt 0 ] 2>/dev/null         && bashio::log.info "  syslog TCP :${syslog_tcp_port}"
[ "${syslog_udp_port:-0}" -gt 0 ] 2>/dev/null         && bashio::log.info "  syslog UDP :${syslog_udp_port}"
[ "${vector_source_port:-0}" -gt 0 ] 2>/dev/null      && bashio::log.info "  vector-in  :${vector_source_port}"
bashio::log.info "Sink: ${sink_type}"
bashio::log.info "Log level: ${log_level} (VECTOR_LOG=${VECTOR_LOG})"
bashio::log.info "API enabled: ${api_enabled}"
bashio::log.info "---"
