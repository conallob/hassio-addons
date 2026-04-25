# Home Assistant Add-on: Vector

## Overview

Vector is a high-performance observability data pipeline. Use it to collect,
transform, and route logs and metrics from your Home Assistant instance to any
destination.

Configure Vector entirely from the Home Assistant add-on UI — no config file
editing required. For advanced use cases, supply a raw Vector YAML config via
the `vector_config` override.

---

## Sources

Any combination of sources can be enabled simultaneously.

### Option: `ha_logs`

Tail `/config/home-assistant.log` and feed every new line into the pipeline.

Default: `true`

### Option: `ha_logs_vrl`

[Vector Remap Language (VRL)](https://vector.dev/docs/reference/vrl/) expression
applied only to HA log events, before they reach the sink. Use this to parse,
enrich, or filter log lines.

Example — parse the structured log format into fields:

```
. = parse_regex!(.message, r'^(?P<timestamp>\S+ \S+) (?P<level>\w+) \((?P<thread>[^)]+)\) \[(?P<logger>[^\]]+)\] (?P<msg>.*)$')
.level = downcase(string!(.level))
```

Default: `""` (no transform)

### Option: `syslog_tcp_port`

Open a syslog TCP listener on this port (e.g. `6000`). Set to `0` to disable.
Also map the port in the add-on Network settings and configure your devices
to send syslog to your Home Assistant IP on this port.

Default: `0` (disabled)

### Option: `syslog_udp_port`

Open a syslog UDP listener on this port (e.g. `6000`). Set to `0` to disable.

Default: `0` (disabled)

### Option: `vector_source_port`

Listen for events from other Vector agents (Vector native protocol v2) on this
port (e.g. `9000`). Set to `0` to disable. Useful for aggregating from remote
Vector agents running on other hosts.

Default: `0` (disabled)

---

## Transforms

### Option: `sink_vrl`

[VRL](https://vector.dev/docs/reference/vrl/) expression applied to **all**
events from all sources, immediately before the sink. Use this for global
enrichment or filtering regardless of source.

Example — drop debug events:

```
if .level == "debug" { abort }
```

Example — add a static label:

```
.environment = "home"
```

Default: `""` (no transform)

---

## Sink

### Option: `sink_type`

Where to send processed events. One of:

| Value | Description |
|-------|-------------|
| `console` | Print events as JSON to the add-on log **(default)** |
| `loki` | Forward to a Loki instance (requires `loki_url`) |
| `elasticsearch` | Forward to Elasticsearch (requires `elasticsearch_url`) |
| `http` | POST as newline-delimited JSON to any HTTP endpoint (requires `http_url`) |
| `gcp` | Forward to GCP Cloud Logging (requires `gcp_project_id` and `gcp_credentials_json`) |
| `none` | Discard all events (useful for testing sources/transforms) |

### Option: `loki_url`

Loki push endpoint. Required when `sink_type` is `loki`.

Example: `http://192.168.1.100:3100`

### Option: `elasticsearch_url`

Elasticsearch endpoint. Required when `sink_type` is `elasticsearch`.

Example: `http://192.168.1.100:9200`

### Option: `http_url`

HTTP endpoint URI. Required when `sink_type` is `http`.

### Option: `sink_auth_username` / `sink_auth_password`

HTTP Basic Auth credentials for Loki, Elasticsearch, or HTTP sinks.
Leave blank for unauthenticated endpoints.

### Option: `gcp_project_id`

GCP project ID to send logs to. Required when `sink_type` is `gcp`.

### Option: `gcp_log_id`

The log stream name within Cloud Logging. Appears as the log name in the
GCP console. Default: `home_assistant`.

### Option: `gcp_credentials_json`

The full contents of a GCP service account JSON key file. Required when
`sink_type` is `gcp`. The add-on writes this to a temporary file at startup
so Vector can authenticate without requiring manual file placement on the host.

To generate a key:
1. GCP Console → IAM & Admin → Service Accounts
2. Create a service account with the **Logs Writer** role (`roles/logging.logWriter`)
3. Create a JSON key and paste the entire file contents here

---

## General

### Option: `log_level`

Add-on log verbosity. Possible values: `trace`, `debug`, `info`, `notice`,
`warning`, `error`, `fatal`.

Default: `info`

### Option: `api_enabled`

Enable the Vector GraphQL API on port **8686**. Useful for querying Vector's
internal metrics and topology at runtime.

Default: `true`

### Option: `vector_config`

Supply a complete raw Vector YAML configuration. **When set, all other options
are ignored** — the raw config is written directly to disk and Vector is started
with it. Use this for pipelines that cannot be expressed with the structured
options above.

Example:

```yaml
sources:
  ha_logs:
    type: file
    include:
      - /config/home-assistant.log
    read_from: beginning

sinks:
  console:
    type: console
    inputs:
      - ha_logs
    target: stdout
    encoding:
      codec: json
```

Default: `""` (use structured options)

---

## Ports

| Port | Purpose |
|------|---------|
| 8686 | Vector API (when `api_enabled: true`) |
| Configurable | Syslog TCP (`syslog_tcp_port`) |
| Configurable | Syslog UDP (`syslog_udp_port`) |
| Configurable | Vector-to-Vector source (`vector_source_port`) |

## Mapped Volumes

| Path | Access | Description |
|------|--------|-------------|
| `/config` | read-write | Home Assistant configuration and logs |
| `/share` | read-write | Shared storage between add-ons |
| `/ssl` | read-only | SSL certificates |

## Vector Documentation

- [Vector documentation](https://vector.dev/docs/)
- [VRL reference](https://vector.dev/docs/reference/vrl/)
- [Sources](https://vector.dev/docs/reference/configuration/sources/)
- [Sinks](https://vector.dev/docs/reference/configuration/sinks/)
