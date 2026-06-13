# Conall's Home Assistant Add-ons

My personal collection of add-ons for [Home Assistant](https://www.home-assistant.io/).

## Installation

Add this repository to your Home Assistant add-on store:

[![Add repository](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fconallob%2Fhassio-addons)

Or manually: **Settings** → **Add-ons** → **Add-on Store** → **⋮** → **Repositories** and add `https://github.com/conallob/hassio-addons`.

---

## Add-ons

### [Grafana Alloy](https://github.com/conallob/hassio-addons/tree/master/alloy)

**Version**: 1.8.3

Grafana Alloy observability collector — scrape Home Assistant Prometheus metrics and/or forward logs to Loki

[Grafana Alloy](https://grafana.com/oss/alloy-opentelemetry-collector/) is an
OpenTelemetry-compatible observability collector. This add-on can:

- **Scrape Home Assistant Prometheus metrics** and remote-write them to Grafana
  Cloud, Mimir, Prometheus, or any compatible endpoint.
- **Forward Home Assistant logs** to Loki or any Loki-compatible endpoint.
- Run **both simultaneously**, or accept a **fully custom Alloy River config**
  for advanced pipelines.

### Installation

1. Add `https://github.com/conallob/hassio-addons` to your add-on store.
2. Install **Grafana Alloy**.
3. Configure the options below and start the add-on.

### Configuration

#### Scrape Home Assistant Prometheus metrics

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

#### Forward Home Assistant logs to Loki

```yaml
collect_logs: true
loki_url: "https://logs-prod-xx.grafana.net/loki/api/v1/push"
```

#### Both at once

```yaml
collect_prometheus: true
collect_logs: true
remote_write_url: "https://prometheus-prod-xx.grafana.net/api/prom/push"
remote_write_username: "<user>"
remote_write_password: "<key>"
loki_url: "https://logs-prod-xx.grafana.net/loki/api/v1/push"
```

#### Custom Alloy River config

Set `alloy_config` to a full [Alloy River](https://grafana.com/docs/alloy/)
configuration string. When set, all other collection options are ignored.

### Options

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

### Ports

| Port | Purpose |
|------|---------|
| 12345 | Alloy HTTP UI and API |

### Prerequisites

- For Prometheus metrics: enable the [Prometheus integration](https://www.home-assistant.io/integrations/prometheus/) in Home Assistant.
- For log forwarding: a running Loki instance (local or Grafana Cloud).

### More information

- [Grafana Alloy documentation](https://grafana.com/docs/alloy/)
- [Alloy River config reference](https://grafana.com/docs/alloy/latest/reference/)

---
### [ntfy](https://github.com/conallob/hassio-addons/tree/master/ntfy)

**Version**: 2.11.4

Self-hosted push notification server with optional SSL support via the HA Let's Encrypt add-on

Self-hosted push notification server ([ntfy.sh](https://ntfy.sh)) with Home Assistant ingress support and optional HTTPS via the HA Let's Encrypt add-on.

### Features

- **Home Assistant Ingress**: Access the ntfy web UI directly from the Home Assistant sidebar
- **SSL support**: Use certificates issued by the [Home Assistant Let's Encrypt add-on](https://github.com/home-assistant/addons/tree/master/letsencrypt)
- **Persistent storage**: Message cache, user database, and attachments survive restarts
- **iOS push support**: Upstream relay to ntfy.sh for instant iOS notifications

### Installation

1. Add this repository to your Home Assistant add-on store
2. Install the **ntfy** add-on
3. Configure the add-on options (see below)
4. Start the add-on

### Configuration

#### Minimal (ingress only, no external access)

No configuration needed. Start the add-on and access ntfy through the Home Assistant sidebar.

#### With SSL (recommended for external access)

SSL certificates are managed by the [Home Assistant Let's Encrypt add-on](https://github.com/home-assistant/addons/tree/master/letsencrypt). The LE add-on issues the certificate and copies it to the shared `/ssl/` directory that ntfy reads from. Both add-ons must be configured with matching filenames.

**Step 1** — Configure the HA Let's Encrypt add-on to issue a cert for your ntfy domain and copy it to `/ssl/` with a unique filename:

```yaml
## HA Let's Encrypt add-on configuration
domains:
  - ntfy.example.com
certfile: ntfy.pem
keyfile: ntfy.key
```

**Step 2** — Configure ntfy to use those same filenames:

```yaml
## ntfy add-on configuration
domain: "ntfy.example.com"
ssl: true
certfile: "ntfy.pem"
keyfile: "ntfy.key"
auth_default_access: "deny-all"
```

**Step 3** — Run the HA Let's Encrypt add-on to issue/renew the certificate, then start ntfy.

Ensure port 443 is forwarded from your router to your Home Assistant host for external HTTPS access. The LE add-on handles renewal automatically; restart ntfy after each renewal to pick up the new certificate.

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `domain` | `""` | Public domain name for external access |
| `ssl` | `false` | Enable HTTPS using certificates from `/ssl/` |
| `certfile` | `fullchain.pem` | SSL certificate filename (relative to `/ssl/`) |
| `keyfile` | `privkey.pem` | SSL private key filename (relative to `/ssl/`) |
| `auth_default_access` | `read-write` | Default access: `read-write`, `read-only`, `write-only`, `deny-all` |
| `upstream_base_url` | `https://ntfy.sh` | Upstream server for iOS push notifications |
| `log_level` | `info` | Log verbosity: `trace`, `debug`, `info`, `warn`, `error` |

### Ports

| Port | Purpose |
|------|---------|
| 443 | ntfy HTTPS API (optional, requires `ssl: true`) |

### Usage

#### Send a notification

```bash
curl -d "Hello from Home Assistant" https://ntfy.example.com/my-topic
```

#### Subscribe in the ntfy app

Point the ntfy Android/iOS app at `https://ntfy.example.com` and subscribe to your topics.

#### Home Assistant automations

Use the [REST command](https://www.home-assistant.io/integrations/rest_command/) integration:

```yaml
rest_command:
  ntfy_notify:
    url: "https://ntfy.example.com/my-topic"
    method: POST
    content_type: "application/json"
    payload: '{"message": "{{ message }}", "title": "{{ title }}"}'
```

### More information

- [ntfy documentation](https://docs.ntfy.sh/)
- [ntfy GitHub](https://github.com/binwiederhier/ntfy)
- [Home Assistant Let's Encrypt add-on](https://github.com/home-assistant/addons/tree/master/letsencrypt)

---
### [Obsidian Headless](https://github.com/conallob/hassio-obsidian-headless)

**Version**: 0.0.3  **Image**: external (`ghcr.io/conallob/hassio-obsidian-headless`)

Syncs your Obsidian vault via Obsidian Sync (headless daemon). Optionally exposes the vault as a remote MCP server with bearer-token or OAuth 2.1 authentication. Supports Tailscale and direct HTTPS access.

> The container image for this add-on is built and published by [https://github.com/conallob/hassio-obsidian-headless](https://github.com/conallob/hassio-obsidian-headless). Only the Home Assistant add-on metadata is hosted in this repository.

This add-on provides two services in a single container:

1. **Obsidian Sync daemon** (`obsidian-headless`) — keeps a local copy of your
   vault continuously synced via your Obsidian Sync subscription. No GUI required.

2. **Obsidian MCP server** (`obsidian-web-mcp`) — exposes your vault as a
   remote MCP server over HTTP with OAuth 2.1 or JWT authentication, allowing
   Claude.ai (and other MCP clients) to read and write your notes from anywhere.

---

### Requirements

- An active **Obsidian Sync** subscription
- Your vault must be set up in Obsidian Sync before configuring this add-on
- If your vault uses **end-to-end encryption**, you will need the vault encryption
  password (distinct from your Obsidian account password)

---

### Step 1: Get your Obsidian Auth Token

The add-on includes a built-in token generator — no Node.js or CLI tools required.

1. Start the add-on (it will start even without a token configured)
2. Open **`http://<your-ha-ip>:8422/`** in your browser
3. Enter your Obsidian account email and password (and 2FA code if enabled)
4. Copy the token shown and paste it into `obsidian_auth_token` in the add-on config
5. Restart the add-on

> Your credentials go directly to `api.obsidian.md` via the add-on server and are
> never stored or logged.

**Alternative (CLI, requires Node 22):**
```bash
npx obsidian-headless@0.0.9 get-token
```
Note: Node 26+ is not yet supported by this command due to a `better-sqlite3`
compatibility issue. Use the browser UI above instead.

---

### Step 2: Find your Vault Name

```bash
OBSIDIAN_AUTH_TOKEN=<your-token> npx obsidian-headless sync-list-remote
```

The vault name is case-sensitive. Use exactly the name shown.

---

### Step 3: Choose your authentication mode

#### JWT (simpler — recommended for Tailscale users)

Generate a secret key:

```bash
openssl rand -hex 32
```

Set `mcp_auth_mode: jwt` and paste the output as `mcp_auth_secret_key`.

#### OAuth 2.1 (required for Claude.ai remote MCP)

You will need an OAuth provider. Options:
- **Google**: use `https://accounts.google.com` as the issuer URL
- **Authentik / Keycloak**: self-hosted options that work well with HA

Set `mcp_auth_mode: oauth` and fill in `oauth_issuer_url` and `oauth_audience`.

---

### Step 4: Choose your tunnel mode

#### `none` — local network only
The MCP server is reachable at `http://<ha-ip>:3010`. Suitable if your MCP
client is on the same network.

#### `tailscale` — Tailscale Funnel
The add-on will bring up a Tailscale node named `obsidian-mcp-ha` on your
tailnet. Generate a reusable auth key at:
https://login.tailscale.com/admin/settings/keys

Your MCP endpoint will be: `https://obsidian-mcp-ha.<your-tailnet>.ts.net/mcp`

#### `https` — direct TLS
Place your certificate files in the HA `/ssl` directory (or `/share`) and
set `tls_cert_path` / `tls_key_path` accordingly. The HA SSL directory is
automatically mapped.

Your MCP endpoint will be: `https://<your-domain>:3010/mcp`

---

### Connecting Claude.ai

In Claude.ai → Settings → Integrations → Add MCP Server:

- **URL**: your MCP endpoint (Tailscale or HTTPS URL above + `/mcp`)
- **Auth**: OAuth 2.1 (if using oauth mode) or Bearer token (if using jwt mode)

---

### Vault location

The synced vault is stored at `/share/obsidian-vault` on your HA host.
This is accessible from other add-ons and from the HA file system.

---

### Troubleshooting

- Check logs via **Settings → Add-ons → Obsidian MCP → Log**
- Set `mcp_log_level: debug` for verbose output
- Ensure your vault name matches exactly (run `sync-list-remote` to confirm)
- If E2E encryption is enabled, `vault_password` must be set or sync will fail

---
### [Vector](https://github.com/conallob/hassio-addons/tree/master/vector)

**Version**: 0.48.0

High-performance observability data pipeline

### Overview

Vector is a high-performance observability data pipeline. Use it to collect,
transform, and route logs and metrics from your Home Assistant instance to any
destination.

Configure Vector entirely from the Home Assistant add-on UI — no config file
editing required. For advanced use cases, supply a raw Vector YAML config via
the `vector_config` override.

---

### Sources

Any combination of sources can be enabled simultaneously.

#### Option: `ha_logs`

Tail `/config/home-assistant.log` and feed every new line into the pipeline.

Default: `true`

#### Option: `ha_logs_vrl`

[Vector Remap Language (VRL)](https://vector.dev/docs/reference/vrl/) expression
applied only to HA log events, before they reach the sink. Use this to parse,
enrich, or filter log lines.

Example — parse the structured log format into fields:

```
. = parse_regex!(.message, r'^(?P<timestamp>\S+ \S+) (?P<level>\w+) \((?P<thread>[^)]+)\) \[(?P<logger>[^\]]+)\] (?P<msg>.*)$')
.level = downcase(string!(.level))
```

Default: `""` (no transform)

#### Option: `syslog_tcp_port`

Open a syslog TCP listener on this port (e.g. `6000`). Set to `0` to disable.
Also map the port in the add-on Network settings and configure your devices
to send syslog to your Home Assistant IP on this port.

Default: `0` (disabled)

#### Option: `syslog_udp_port`

Open a syslog UDP listener on this port (e.g. `6000`). Set to `0` to disable.

Default: `0` (disabled)

#### Option: `vector_source_port`

Listen for events from other Vector agents (Vector native protocol v2) on this
port (e.g. `9000`). Set to `0` to disable. Useful for aggregating from remote
Vector agents running on other hosts.

Default: `0` (disabled)

---

### Transforms

#### Option: `sink_vrl`

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

### Sink

#### Option: `sink_type`

Where to send processed events. One of:

| Value | Description |
|-------|-------------|
| `console` | Print events as JSON to the add-on log **(default)** |
| `loki` | Forward to a Loki instance (requires `loki_url`) |
| `elasticsearch` | Forward to Elasticsearch (requires `elasticsearch_url`) |
| `http` | POST as newline-delimited JSON to any HTTP endpoint (requires `http_url`) |
| `gcp` | Forward to GCP Cloud Logging (requires `gcp_project_id` and `gcp_credentials_json`) |
| `none` | Discard all events (useful for testing sources/transforms) |

#### Option: `loki_url`

Loki push endpoint. Required when `sink_type` is `loki`.

Example: `http://192.168.1.100:3100`

#### Option: `elasticsearch_url`

Elasticsearch endpoint. Required when `sink_type` is `elasticsearch`.

Example: `http://192.168.1.100:9200`

#### Option: `http_url`

HTTP endpoint URI. Required when `sink_type` is `http`.

#### Option: `sink_auth_username` / `sink_auth_password`

HTTP Basic Auth credentials for Loki, Elasticsearch, or HTTP sinks.
Leave blank for unauthenticated endpoints.

#### Option: `gcp_project_id`

GCP project ID to send logs to. Required when `sink_type` is `gcp`.

#### Option: `gcp_log_id`

The log stream name within Cloud Logging. Appears as the log name in the
GCP console. Default: `home_assistant`.

#### Option: `gcp_credentials_json`

The full contents of a GCP service account JSON key file. Required when
`sink_type` is `gcp`. The add-on writes this to a temporary file at startup
so Vector can authenticate without requiring manual file placement on the host.

To generate a key:
1. GCP Console → IAM & Admin → Service Accounts
2. Create a service account with the **Logs Writer** role (`roles/logging.logWriter`)
3. Create a JSON key and paste the entire file contents here

---

### General

#### Option: `log_level`

Add-on log verbosity. Possible values: `trace`, `debug`, `info`, `notice`,
`warning`, `error`, `fatal`.

Default: `info`

#### Option: `api_enabled`

Enable the Vector GraphQL API on port **8686**. Useful for querying Vector's
internal metrics and topology at runtime.

Default: `true`

#### Option: `vector_config`

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

### Ports

| Port | Purpose |
|------|---------|
| 8686 | Vector API (when `api_enabled: true`) |
| Configurable | Syslog TCP (`syslog_tcp_port`) |
| Configurable | Syslog UDP (`syslog_udp_port`) |
| Configurable | Vector-to-Vector source (`vector_source_port`) |

### Mapped Volumes

| Path | Access | Description |
|------|--------|-------------|
| `/config` | read-write | Home Assistant configuration and logs |
| `/share` | read-write | Shared storage between add-ons |
| `/ssl` | read-only | SSL certificates |

### Vector Documentation

- [Vector documentation](https://vector.dev/docs/)
- [VRL reference](https://vector.dev/docs/reference/vrl/)
- [Sources](https://vector.dev/docs/reference/configuration/sources/)
- [Sinks](https://vector.dev/docs/reference/configuration/sinks/)

---
