#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Grafana Alloy add-on initialization
# Generates alloy.river config from add-on options before the service starts
# ==============================================================================

declare log_level
declare collect_prometheus
declare collect_logs
declare prometheus_scrape_interval
declare loki_url
declare remote_write_url
declare remote_write_username
declare remote_write_password
declare alloy_config
declare ha_token

ALLOY_CONFIG_PATH="/etc/alloy/config.alloy"

# ---------------------------------------------------------------------------
# Read configuration from Home Assistant add-on options
# ---------------------------------------------------------------------------
log_level=$(bashio::config 'log_level')
collect_prometheus=$(bashio::config 'collect_prometheus')
collect_logs=$(bashio::config 'collect_logs')
prometheus_scrape_interval=$(bashio::config 'prometheus_scrape_interval')
loki_url=$(bashio::config 'loki_url')
remote_write_url=$(bashio::config 'remote_write_url')
remote_write_username=$(bashio::config 'remote_write_username')
remote_write_password=$(bashio::config 'remote_write_password')
alloy_config=$(bashio::config 'alloy_config')

# The Supervisor long-lived token is available via env; use it to authenticate
# against the Home Assistant Prometheus endpoint.
ha_token="${SUPERVISOR_TOKEN}"

# ---------------------------------------------------------------------------
# Validate options
# ---------------------------------------------------------------------------
if ! bashio::var.true "${collect_prometheus}" && ! bashio::var.true "${collect_logs}"; then
    if ! bashio::var.has_value "${alloy_config}"; then
        bashio::log.fatal "At least one of collect_prometheus or collect_logs must be enabled, or a custom alloy_config must be provided"
        bashio::exit.nok
    fi
fi

if bashio::var.true "${collect_logs}" && ! bashio::var.has_value "${loki_url}"; then
    bashio::log.fatal "collect_logs is enabled but loki_url is not configured"
    bashio::exit.nok
fi

if bashio::var.true "${collect_prometheus}" && ! bashio::var.has_value "${remote_write_url}"; then
    bashio::log.warning "collect_prometheus is enabled but remote_write_url is not set — metrics will be scraped but not forwarded"
fi

# ---------------------------------------------------------------------------
# Generate Alloy River configuration
# ---------------------------------------------------------------------------
bashio::log.info "Generating Alloy configuration..."

if bashio::var.has_value "${alloy_config}"; then
    # User supplied a fully custom config — write it verbatim
    printf '%s\n' "${alloy_config}" > "${ALLOY_CONFIG_PATH}"
    bashio::log.info "Using custom alloy_config"
else
    {
        # ------------------------------------------------------------------
        # Prometheus collection: scrape HA's built-in Prometheus endpoint
        # ------------------------------------------------------------------
        if bashio::var.true "${collect_prometheus}"; then
            cat <<PROMETHEUS_BLOCK
// Scrape Home Assistant Prometheus metrics via the Supervisor proxy
prometheus.scrape "home_assistant" {
  targets = [{"__address__" = "supervisor/core/api/prometheus", "__scheme__" = "http"}]
  scrape_interval = "${prometheus_scrape_interval}"
  authorization {
    type        = "Bearer"
    credentials = "${ha_token}"
  }
  forward_to = [prometheus.relabel.ha_metrics.receiver]
}

// Add a static label to identify the source
prometheus.relabel "ha_metrics" {
  rule {
    target_label = "job"
    replacement  = "home_assistant"
  }
  forward_to = [${remote_write_url:+prometheus.remote_write.default.receiver}]
}

PROMETHEUS_BLOCK

            if bashio::var.has_value "${remote_write_url}"; then
                cat <<REMOTE_WRITE_BLOCK
prometheus.remote_write "default" {
  endpoint {
    url = "${remote_write_url}"
REMOTE_WRITE_BLOCK

                if bashio::var.has_value "${remote_write_username}"; then
                    cat <<AUTH_BLOCK
    basic_auth {
      username = "${remote_write_username}"
      password = "${remote_write_password}"
    }
AUTH_BLOCK
                fi

                cat <<REMOTE_WRITE_END
  }
}

REMOTE_WRITE_END
            fi
        fi

        # ------------------------------------------------------------------
        # Log collection: tail Home Assistant log and forward to Loki
        # ------------------------------------------------------------------
        if bashio::var.true "${collect_logs}"; then
            cat <<LOGS_BLOCK
// Tail the Home Assistant log file
local.file_match "ha_logs" {
  path_targets = [{"__path__" = "/config/home-assistant.log"}]
}

loki.source.file "ha_logs" {
  targets    = local.file_match.ha_logs.targets
  forward_to = [loki.process.ha_logs.receiver]
}

// Add static labels before forwarding
loki.process "ha_logs" {
  stage.static_labels {
    values = {
      job  = "home_assistant",
      host = "homeassistant",
    }
  }
  forward_to = [loki.write.default.receiver]
}

loki.write "default" {
  endpoint {
    url = "${loki_url}"
  }
}

LOGS_BLOCK
        fi

    } > "${ALLOY_CONFIG_PATH}"
fi

bashio::log.info "Alloy configuration written to ${ALLOY_CONFIG_PATH}"
bashio::log.info "Collect Prometheus: ${collect_prometheus}"
bashio::log.info "Collect logs: ${collect_logs}"
bashio::log.info "Log level: ${log_level}"

# Export log level for the s6 service
printf '%s' "${log_level}" > /var/run/s6/container_environment/ALLOY_LOG_LEVEL
