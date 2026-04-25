# Grafana Alloy — Home Assistant Add-on

[Grafana Alloy](https://grafana.com/oss/alloy-opentelemetry-collector/) is an
OpenTelemetry-compatible observability collector. This add-on can:

- **Scrape Home Assistant Prometheus metrics** and remote-write them to Grafana
  Cloud, Mimir, Prometheus, or any compatible endpoint.
- **Forward Home Assistant logs** to Loki or any Loki-compatible endpoint.
- Run **both simultaneously**, or accept a **fully custom Alloy River config**
  for advanced pipelines.

## Installation

1. Add `https://github.com/conallob/hassio-addons` to your add-on store.
2. Install **Grafana Alloy**.
3. Configure the options below and start the add-on.

## Configuration

### Scrape Home Assistant Prometheus metrics

```yaml
collect_prometheus: true
prometheus_scrape_interval: "60s"
remote_write_url: "https://prometheus-prod-xx.grafana.net/api/prom/push"
remote_write_username: "<Grafana Cloud user ID>"
remote_write_password: "<Grafana Cloud API key>"
```

Home Assistant exposes a Prometheus endpoint at `/api/prometheus` (requires the
[Prometheus integration](https://www.home-assistant.io/integrations/prometheus/)
to be enabled). The add-on authenticates using the Supervisor token
automatically — no manual token configuration needed.

### Forward Home Assistant logs to Loki

```yaml
collect_logs: true
loki_url: "https://logs-prod-xx.grafana.net/loki/api/v1/push"
```

### Both at once

```yaml
collect_prometheus: true
collect_logs: true
remote_write_url: "https://prometheus-prod-xx.grafana.net/api/prom/push"
remote_write_username: "<user>"
remote_write_password: "<key>"
loki_url: "https://logs-prod-xx.grafana.net/loki/api/v1/push"
```

### Custom Alloy River config

Set `alloy_config` to a full [Alloy River](https://grafana.com/docs/alloy/)
configuration string. When set, all other collection options are ignored.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `log_level` | `info` | Alloy log verbosity |
| `collect_prometheus` | `true` | Scrape HA Prometheus endpoint |
| `collect_logs` | `false` | Tail HA log and forward to Loki |
| `prometheus_scrape_interval` | `60s` | How often to scrape metrics |
| `remote_write_url` | `""` | Prometheus remote_write endpoint |
| `remote_write_username` | `""` | HTTP Basic auth username |
| `remote_write_password` | `""` | HTTP Basic auth password |
| `loki_url` | `""` | Loki push endpoint |
| `alloy_config` | `""` | Fully custom Alloy River config (overrides all above) |

## Ports

| Port | Purpose |
|------|---------|
| 12345 | Alloy HTTP UI and API |

## Prerequisites

- For Prometheus metrics: enable the [Prometheus integration](https://www.home-assistant.io/integrations/prometheus/) in Home Assistant.
- For log forwarding: a running Loki instance (local or Grafana Cloud).

## More information

- [Grafana Alloy documentation](https://grafana.com/docs/alloy/)
- [Alloy River config reference](https://grafana.com/docs/alloy/latest/reference/)
