#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Cloudprober add-on initialization
# Generates /data/cloudprober/cloudprober.cfg from add-on options.
#
# The generated file is the `cloudprober_config` option verbatim (native
# Cloudprober textproto), plus — when `extra_config_path` is set — an
# `include "<relative path>"` line pointing at a file (or glob) under
# /homeassistant, so extra probes can live in your git-managed HA config.
#
# Cloudprober resolves `include` paths relative to the *including* file's
# directory (and runs them through filepath.Join), so an absolute path can't
# be used directly; the relative path is computed here instead.
#
# The result is validated with `cloudprober -configtest` before the service
# starts. Home Assistant has no "on save" hook for add-ons, so this runs on
# every (re)start — the earliest point the add-on can act on new options or a
# freshly pulled extra config file.
# ==============================================================================

declare log_level
declare extra_config_path
declare cloudprober_config

HA_CONFIG_ROOT="/homeassistant"
CLOUDPROBER_CONFIG_DIR="/data/cloudprober"
CLOUDPROBER_CONFIG_PATH="${CLOUDPROBER_CONFIG_DIR}/cloudprober.cfg"

mkdir -p "${CLOUDPROBER_CONFIG_DIR}"

log_level=$(bashio::config 'log_level')
extra_config_path=$(bashio::config 'extra_config_path')
cloudprober_config=$(bashio::config 'cloudprober_config')

# Cloudprober has no log-level flag; this only sets the add-on's own bashio
# log verbosity.
bashio::log.level "${log_level}"

# ---------------------------------------------------------------------------
# Resolve and validate extra_config_path
# ---------------------------------------------------------------------------
include_line=""
if bashio::var.has_value "${extra_config_path}"; then
    # Accept both "cloudprober/extra.cfg" and "/homeassistant/cloudprober/extra.cfg"
    extra_config_path="${extra_config_path#"${HA_CONFIG_ROOT}"/}"
    extra_config_path="${extra_config_path#/}"

    # Reject anything that resolves outside /homeassistant
    resolved=$(realpath -m "${HA_CONFIG_ROOT}/${extra_config_path}")
    case "${resolved}" in
        "${HA_CONFIG_ROOT}"/*) ;;
        *)
            bashio::log.fatal "extra_config_path must be inside ${HA_CONFIG_ROOT} (resolved to ${resolved})."
            bashio::exit.nok
            ;;
    esac

    # Cloudprober fails on an include that matches nothing; check first so the
    # error names the path instead of surfacing as an opaque startup failure.
    # shellcheck disable=SC2086  # glob expansion is intentional
    if ! compgen -G "${resolved}" > /dev/null; then
        bashio::log.fatal "extra_config_path matched no files: ${resolved}"
        bashio::log.fatal "Check the path is relative to ${HA_CONFIG_ROOT} and the file exists (e.g. after a git pull)."
        bashio::exit.nok
    fi

    relative=$(realpath -m --relative-to="${CLOUDPROBER_CONFIG_DIR}" "${resolved}")
    include_line="include \"${relative}\""
fi

# ---------------------------------------------------------------------------
# A main config is required — Cloudprober refuses to start with no probes,
# and there is no sensible fallback.
# ---------------------------------------------------------------------------
if ! bashio::var.has_value "${cloudprober_config}" && [ -z "${include_line}" ]; then
    bashio::log.fatal "Both cloudprober_config and extra_config_path are empty. Provide at least one probe definition."
    bashio::exit.nok
fi

# ---------------------------------------------------------------------------
# Write the final config
# ---------------------------------------------------------------------------
{
    if bashio::var.has_value "${cloudprober_config}"; then
        printf '%s\n' "${cloudprober_config}"
    fi
    if [ -n "${include_line}" ]; then
        printf '\n# Included from %s (extra_config_path)\n%s\n' "${resolved}" "${include_line}"
    fi
} > "${CLOUDPROBER_CONFIG_PATH}"

bashio::log.info "Cloudprober configuration written to ${CLOUDPROBER_CONFIG_PATH}"
if [ -n "${include_line}" ]; then
    bashio::log.info "Including extra config: ${resolved} (as ${include_line})"
else
    bashio::log.info "No extra_config_path set — using cloudprober_config only"
fi

# ---------------------------------------------------------------------------
# Warn if the config sets its own grpc_port: it overrides grpc_enabled, and
# only 9314 is declared in config.yaml's ports, so any other port can't be
# published from the add-on's Network settings.
# ---------------------------------------------------------------------------
if grep -qE '^[[:space:]]*grpc_port[[:space:]]*:[[:space:]]*[0-9]+' "${CLOUDPROBER_CONFIG_PATH}"; then
    grpc_cfg_port=$(grep -E '^[[:space:]]*grpc_port[[:space:]]*:' "${CLOUDPROBER_CONFIG_PATH}" | head -n1 | grep -oE '[0-9]+')
    bashio::log.info "grpc_port ${grpc_cfg_port} is set in the config; it takes precedence over grpc_enabled"
    if [ "${grpc_cfg_port}" != "9314" ]; then
        bashio::log.warning "Only 9314/tcp is declared by the add-on, so grpc_port ${grpc_cfg_port} can't be published to the host."
    fi
fi

# ---------------------------------------------------------------------------
# Validate the generated config (including the included extra file) with
# Cloudprober's own dry-run. `-configtest` loads the config the same way a
# normal start does, runs the extra checks (durations, validators, targets),
# and exits non-zero on error — so a bad config is reported clearly here
# instead of crash-looping the service.
# ---------------------------------------------------------------------------
if ! test_output=$(/usr/bin/cloudprober --config_file "${CLOUDPROBER_CONFIG_PATH}" -configtest 2>&1); then
    bashio::log.fatal "Cloudprober config test failed:"
    while IFS= read -r line; do
        bashio::log.fatal "  ${line}"
    done <<< "${test_output}"
    bashio::exit.nok
fi
bashio::log.info "Cloudprober config test passed"
