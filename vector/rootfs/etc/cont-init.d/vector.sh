#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Vector add-on initialization
# Generates /config/vector/vector.yaml from add-on options — unless
# config_mode is "directory", in which case Vector is started against an
# external config directory instead (see the vector service's run script)
# and this script has nothing to generate.
#
# config_mode:
#   embedded    (default) — build /config/vector/vector.yaml from
#                vector_config/api_enabled/syslog_enabled, as below.
#   directory   — point Vector at config_dir instead, a directory of
#                *.yaml/*.toml/*.json files that this add-on never writes
#                to. Intended for a git-managed checkout (e.g. under
#                /share) so multiple pipeline revisions can be tracked in
#                git and swapped by checking out a different one — nothing
#                the add-on itself needs to know about. api_enabled,
#                syslog_enabled, and vector_config are ignored in this
#                mode; include your own api:/source config in the
#                directory if you need them. vector_config is also
#                actively cleared (via the Supervisor API) so it doesn't
#                keep tracking a stale embedded pipeline while unused.
#
# In embedded mode, the add-on manages a few things on top of vector_config:
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
declare config_mode
declare config_dir
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
config_mode=$(bashio::config 'config_mode')
config_dir=$(bashio::config 'config_dir')
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
# config_mode: directory — Vector loads its pipeline straight from
# config_dir, which this add-on never writes to. Nothing to generate here
# beyond confirming the directory is usable.
# ---------------------------------------------------------------------------
if [ "${config_mode}" = "directory" ]; then
    if ! bashio::var.has_value "${config_dir}"; then
        bashio::log.fatal "config_mode is 'directory' but config_dir is not set."
        bashio::exit.nok
    fi

    mkdir -p "${config_dir}"
    if [ -z "$(find "${config_dir}" -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.toml' -o -name '*.json' \) -print -quit)" ]; then
        bashio::log.warning "config_dir (${config_dir}) has no *.yaml/*.toml/*.json files yet — Vector will fail to start until it does."
    fi

    # Don't leave a stale embedded pipeline sitting in vector_config while
    # it's not being used — clear it via the Supervisor API. Run in a
    # subshell since bashio::api.supervisor can call bashio::exit.nok
    # internally on failure, and that shouldn't take the add-on down.
    if bashio::var.has_value "${vector_config}"; then
        bashio::log.info "config_mode is 'directory' — clearing vector_config so it stops tracking a stale embedded pipeline"
        if ! (bashio::api.supervisor POST "/addons/self/options" '{"options":{"vector_config":""}}') > /dev/null 2>&1; then
            bashio::log.warning "Could not clear vector_config via the Supervisor API; it will remain set but stays ignored while config_mode is 'directory'"
        fi
    fi

    bashio::log.info "config_mode is 'directory' — Vector will load ${config_dir} directly (api_enabled, syslog_enabled, and vector_config are ignored)"
    bashio::log.info "Log level: ${log_level} (VECTOR_LOG=${VECTOR_LOG})"
    bashio::exit.ok
fi

# ---------------------------------------------------------------------------
# config_mode: embedded (default) — generate vector.yaml as before.
# A pipeline is required — there's nothing sensible to fall back to.
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
