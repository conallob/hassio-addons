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
declare gcp_project_id
declare gcp_log_id
declare gcp_credentials_json
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
gcp_project_id=$(bashio::config 'gcp_project_id')
gcp_log_id=$(bashio::config 'gcp_log_id')
gcp_credentials_json=$(bashio::config 'gcp_credentials_json')
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
    gcp)
        if ! bashio::var.has_value "${gcp_project_id}"; then
            bashio::log.fatal "sink_type is 'gcp' but gcp_project_id is not set"
            bashio::exit.nok
        fi
        if ! bashio::var.has_value "${gcp_credentials_json}"; then
            bashio::log.fatal "sink_type is 'gcp' but gcp_credentials_json is not set"
            bashio::exit.nok
        fi
        ;;
esac

# ---------------------------------------------------------------------------
# Write GCP service account credentials to a temp file so Vector can read them.
# The JSON content comes from the add-on option rather than requiring the user
# to place a file on the host filesystem via SSH.
# ---------------------------------------------------------------------------
GCP_CREDENTIALS_PATH="/tmp/vector-gcp-credentials.json"
if [ "${sink_type}" = "gcp" ] && bashio::var.has_value "${gcp_credentials_json}"; then
    printf '%s' "${gcp_credentials_json}" > "${GCP_CREDENTIALS_PATH}"
    chmod 600 "${GCP_CREDENTIALS_PATH}"
    bashio::log.info "GCP credentials written to ${GCP_CREDENTIALS_PATH}"
fi

# ---------------------------------------------------------------------------
# Build input lists as proper YAML entries
# ---------------------------------------------------------------------------
declare -a ALL_INPUTS=()

add_input() {
    ALL_INPUTS+=("$1")
}

# Emit YAML list items at a given indent (number of spaces)
emit_inputs() {
    local indent="$1"
    shift
    local pad=""
    for ((i=0; i<indent; i++)); do pad+=" "; done
    for item in "$@"; do
        printf '%s- %s\n' "${pad}" "${item}"
    done
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

    # --- Collect source IDs into ALL_INPUTS ---
    if bashio::var.true "${ha_logs}" && bashio::var.has_value "${ha_logs_vrl}"; then
        add_input "ha_logs_transform"
    elif bashio::var.true "${ha_logs}"; then
        add_input "ha_logs"
    fi

    [ "${syslog_tcp_port:-0}" -gt 0 ] 2>/dev/null && add_input "syslog_tcp"
    [ "${syslog_udp_port:-0}" -gt 0 ] 2>/dev/null && add_input "syslog_udp"
    [ "${vector_source_port:-0}" -gt 0 ] 2>/dev/null && add_input "vector_in"

    # --- Transforms (only emitted when at least one transform is needed) ---
    HAS_TRANSFORMS=false
    bashio::var.true "${ha_logs}" && bashio::var.has_value "${ha_logs_vrl}" && HAS_TRANSFORMS=true
    bashio::var.has_value "${sink_vrl}" && HAS_TRANSFORMS=true

    if "${HAS_TRANSFORMS}"; then
        echo "transforms:"

        if bashio::var.true "${ha_logs}" && bashio::var.has_value "${ha_logs_vrl}"; then
            echo "  ha_logs_transform:"
            echo "    type: remap"
            echo "    inputs:"
            echo "      - ha_logs"
            echo "    source: |"
            printf '%s\n' "${ha_logs_vrl}" | sed 's/^/      /'
            echo ""
        fi

        if bashio::var.has_value "${sink_vrl}"; then
            echo "  sink_transform:"
            echo "    type: remap"
            echo "    inputs:"
            emit_inputs 6 "${ALL_INPUTS[@]}"
            echo "    source: |"
            printf '%s\n' "${sink_vrl}" | sed 's/^/      /'
            echo ""
            SINK_INPUTS=("sink_transform")
        else
            SINK_INPUTS=("${ALL_INPUTS[@]}")
        fi
    else
        SINK_INPUTS=("${ALL_INPUTS[@]}")
    fi

    # --- Sink ---
    echo "sinks:"

    if [ "${sink_type}" = "none" ]; then
        echo "  blackhole:"
        echo "    type: blackhole"
        echo "    inputs:"
        emit_inputs 6 "${SINK_INPUTS[@]}"

    elif [ "${sink_type}" = "console" ]; then
        echo "  console:"
        echo "    type: console"
        echo "    inputs:"
        emit_inputs 6 "${SINK_INPUTS[@]}"
        echo "    target: stdout"
        echo "    encoding:"
        echo "      codec: json"

    elif [ "${sink_type}" = "loki" ]; then
        echo "  loki:"
        echo "    type: loki"
        echo "    inputs:"
        emit_inputs 6 "${SINK_INPUTS[@]}"
        echo "    endpoint: \"${loki_url}\""
        echo "    labels:"
        echo "      job: home_assistant"
        echo '      host: "{{ host }}"'
        echo "    encoding:"
        echo "      codec: json"
        if bashio::var.has_value "${sink_auth_username}"; then
            echo "    auth:"
            echo "      strategy: basic"
            echo "      user: \"${sink_auth_username}\""
            echo "      password: \"${sink_auth_password}\""
        fi

    elif [ "${sink_type}" = "elasticsearch" ]; then
        echo "  elasticsearch:"
        echo "    type: elasticsearch"
        echo "    inputs:"
        emit_inputs 6 "${SINK_INPUTS[@]}"
        echo "    endpoints:"
        echo "      - \"${elasticsearch_url}\""
        if bashio::var.has_value "${sink_auth_username}"; then
            echo "    auth:"
            echo "      strategy: basic"
            echo "      user: \"${sink_auth_username}\""
            echo "      password: \"${sink_auth_password}\""
        fi

    elif [ "${sink_type}" = "http" ]; then
        echo "  http_out:"
        echo "    type: http"
        echo "    inputs:"
        emit_inputs 6 "${SINK_INPUTS[@]}"
        echo "    uri: \"${http_url}\""
        echo "    encoding:"
        echo "      codec: json"
        echo "    framing:"
        echo "      method: newline_delimited"
        if bashio::var.has_value "${sink_auth_username}"; then
            echo "    auth:"
            echo "      strategy: basic"
            echo "      user: \"${sink_auth_username}\""
            echo "      password: \"${sink_auth_password}\""
        fi

    elif [ "${sink_type}" = "gcp" ]; then
        echo "  gcp:"
        echo "    type: gcp_stackdriver_logs"
        echo "    inputs:"
        emit_inputs 6 "${SINK_INPUTS[@]}"
        echo "    project_id: \"${gcp_project_id}\""
        echo "    log_id: \"${gcp_log_id}\""
        echo "    credentials_path: \"${GCP_CREDENTIALS_PATH}\""
        echo "    resource:"
        echo "      type: generic_node"
        echo "      labels:"
        echo "        node_id: homeassistant"
        echo "        location: global"
        echo "        namespace: home_assistant"
        echo "    severity_key: level"
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
[ "${sink_type}" = "gcp" ] && bashio::log.info "  GCP project: ${gcp_project_id}, log_id: ${gcp_log_id}"
bashio::log.info "Log level: ${log_level} (VECTOR_LOG=${VECTOR_LOG})"
bashio::log.info "API enabled: ${api_enabled}"
bashio::log.info "---"
