#!/bin/bash
set -e

CONFIG_PATH="/data/options.json"
VECTOR_CONFIG_DIR="/config/vector"
VECTOR_CONFIG_PATH="${VECTOR_CONFIG_DIR}/vector.yaml"

mkdir -p "${VECTOR_CONFIG_DIR}"

# ---------------------------------------------------------------------------
# Parse Home Assistant add-on options
# ---------------------------------------------------------------------------
LOG_LEVEL=$(jq -r '.log_level // "info"' "${CONFIG_PATH}")
API_ENABLED=$(jq -r '.api_enabled // true' "${CONFIG_PATH}")
VECTOR_CONFIG=$(jq -r '.vector_config // empty' "${CONFIG_PATH}")

# ---------------------------------------------------------------------------
# Build the Vector configuration file
# ---------------------------------------------------------------------------
{
  # API section – controlled by the api_enabled toggle in the add-on UI
  if [ "${API_ENABLED}" = "true" ]; then
    cat <<'APIBLOCK'
api:
  enabled: true
  address: 0.0.0.0:8686

APIBLOCK
  fi

  # User-supplied sources / transforms / sinks (from the add-on config UI)
  if [ -n "${VECTOR_CONFIG}" ]; then
    printf '%s\n' "${VECTOR_CONFIG}"
  else
    # Fallback to the bundled default template
    cat /etc/vector/vector.yaml.template
  fi
} > "${VECTOR_CONFIG_PATH}"

# ---------------------------------------------------------------------------
# Map Home Assistant log levels to Vector log levels
# ---------------------------------------------------------------------------
case "${LOG_LEVEL}" in
  trace)          VECTOR_LOG="trace" ;;
  debug)          VECTOR_LOG="debug" ;;
  info|notice)    VECTOR_LOG="info"  ;;
  warning)        VECTOR_LOG="warn"  ;;
  error|fatal)    VECTOR_LOG="error" ;;
  *)              VECTOR_LOG="info"  ;;
esac

export VECTOR_LOG

echo "-------------------------------------------------------"
echo " Vector Home Assistant Add-on"
echo " Log level : ${LOG_LEVEL} (VECTOR_LOG=${VECTOR_LOG})"
echo " API       : ${API_ENABLED}"
echo " Config    : ${VECTOR_CONFIG_PATH}"
echo "-------------------------------------------------------"

exec vector --config "${VECTOR_CONFIG_PATH}" --watch-config
