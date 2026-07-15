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

**Version**: 0.0.14  **Image**: external (`ghcr.io/conallob/hassio-obsidian-headless`)

Syncs your Obsidian vault via Obsidian Sync (headless daemon). Optionally exposes the vault as a remote MCP server with bearer-token or OAuth 2.1 authentication. Supports Tailscale and direct HTTPS access.

> The container image for this add-on is built and published by [https://github.com/conallob/hassio-obsidian-headless](https://github.com/conallob/hassio-obsidian-headless). Only the Home Assistant add-on metadata is hosted in this repository.

This add-on provides three services in a single container:

1. **Obsidian Sync daemon** (`obsidian-headless`) — keeps a local copy of your
   vault continuously synced via your Obsidian Sync subscription. No GUI required.

2. **Obsidian MCP server** (`obsidian-web-mcp`) — exposes your vault as a
   **remote, streamable HTTP** MCP server so AI assistants (e.g. Claude.ai) can
   read and search your notes from anywhere — not just from a desktop machine.

3. **reMarkable Cloud sync** (optional) — pulls documents from your reMarkable
   tablet into Obsidian automatically as Markdown notes with embedded PDFs.

---

### Why this add-on vs the alternatives?

| | This add-on | Obsidian Community Plugin MCP servers | mcpvault.org |
|---|---|---|---|
| Hosting | Self-hosted on your HA instance | Self-hosted, runs inside Obsidian desktop | Third-party cloud |
| Obsidian desktop required? | No — syncs headlessly 24/7 | Yes — Obsidian must be open | No |
| MCP transport | **Remote streamable HTTP** | Local stdio / localhost only | HTTP (cloud) |
| Works with Claude.ai web? | **Yes** | No — desktop-only clients only | Yes |
| Works with API/custom clients? | **Yes** | No | Yes |
| Data leaves your network? | No | No | Yes |
| Tunnel options | Local network, Tailscale, HTTPS | None | N/A |

**The key differentiator**: Community plugin MCP servers use the stdio or
localhost transport, which only works with desktop MCP clients (e.g. Claude
Desktop). This add-on serves the streamable HTTP transport over your network,
so any MCP client — including Claude.ai, custom API integrations, and remote
agents — can connect without Obsidian or a desktop machine running.

---

### Requirements

- An active **Obsidian Sync** subscription
- Your vault must already be set up in Obsidian Sync before configuring this add-on
- If your vault uses **end-to-end encryption**, you will need the vault encryption
  password (distinct from your Obsidian account password)

---

### Step 1: Get your Obsidian Auth Token

The auth token is **not** shown anywhere in the Obsidian desktop app UI. The add-on
includes a built-in token generator that handles this for you.

1. Install and **start** the add-on (no configuration needed yet)
2. Open **`http://<your-ha-ip>:8422/`** in your browser
3. Sign in with your Obsidian account email and password (plus 2FA if enabled)
4. The token is **saved automatically** — no copy/paste into config needed
5. Restart the add-on

> Your credentials are sent directly to `api.obsidian.md` — they are never
> stored or logged by the add-on. The resulting token is saved to
> `/data/obsidian.token` and picked up automatically on restart.

If you prefer to set the token explicitly, paste it into `obsidian_auth_token`
in the add-on configuration. A manually configured token takes priority over
the saved file.

**Alternative (if you have Node 22 installed locally):**
```bash
npx obsidian-headless get-token
```

---

### Step 2: Find your Vault Name

The vault name is case-sensitive and must match exactly what Obsidian Sync shows.
To list your remote vaults, run on a machine with Node 22:

```bash
OBSIDIAN_AUTH_TOKEN=<your-token> npx obsidian-headless sync-list-remote
```

Or check the Obsidian desktop app: **Settings → Sync → Remote vault**.

---

### Step 3: Configure the add-on

Minimum required fields:

| Field | Description |
|---|---|
| `vault_name` | Exact vault name from Step 2 |
| `obsidian_auth_token` | Optional — auto-saved by the port 8422 UI; set explicitly to override |
| `vault_password` | Only if your vault uses E2E encryption |

The vault will sync to `/share/obsidian-vault` on your HA host, accessible
from other add-ons and the HA file system.

---

### Optional: MCP Server

Set `enable_mcp: true` to expose your vault as a remote MCP server on port 8420.

#### MCP server runtime

The MCP server itself is [`obsidian-web-mcp`](https://github.com/jimprosser/obsidian-web-mcp),
a third-party **Python** project — this add-on packages and configures it, it is
not code we maintain. It was chosen because it already implements the MCP
protocol (streamable HTTP transport), vault search/indexing, frontmatter
parsing, and Bearer/OAuth 2.1 auth; writing an equivalent from scratch (e.g.
in Go, matching the rest of this add-on's own binaries) would mean
reimplementing all of that.

The trade-off is that the final container image needs a working Python 3.12
runtime. Since Debian bookworm's `apt` only ships Python 3.11, and
`obsidian-web-mcp` requires 3.12+, the Dockerfile copies a self-contained
Python 3.12 runtime out of a `python:3.12-slim-bookworm` builder stage rather
than relying on `apt`. If you see the MCP server crash-looping in the logs
with a `ModuleNotFoundError` or a `GLIBC_x` version error, it almost always
means that runtime copy and the final base image have drifted apart — see
the `Dockerfile` comments around the `mcp-builder` stage for the current
pinning rationale.

#### Network binding

The MCP server listens on `0.0.0.0:8420` inside the container (not `127.0.0.1`),
so it's reachable on your LAN via the published port 8420. What's actually
reachable from outside the container is still controlled by Docker's port
publishing (`ports` in `config.yaml`) and your `tunnel_mode` setting — binding
all interfaces here does not, by itself, expose anything beyond what you've
already opted into. Auth (bearer token and/or OAuth) is enforced regardless
of how the request arrives, except in the local-only, no-tunnel case
described below.

#### Authentication

At least one of these must be set:

- **Bearer token** (`mcp_auth_token`): a long random secret. Generate one with:
  ```bash
  openssl rand -hex 32
  ```
- **OAuth 2.1** (`oauth_client_secret`): for integration with external OAuth providers.
  Set `oauth_client_id` to customise the client ID (default: `vault-mcp-client`).

> **Local-only unauthenticated mode**: if `tunnel_mode: none`, port 8420 does
> _not_ require a bearer token. This is acceptable on a trusted local network.
> Any external path — Tailscale or HTTPS proxy — enforces auth.

#### Tunnel mode (`tunnel_mode`)

| Value | Description |
|---|---|
| `none` (default) | Port 8420 on your local network only |
| `tailscale` | Add-on joins your tailnet; set `tailscale_auth_key` |
| `https` | Expects an external reverse proxy; set `tls_cert_path` / `tls_key_path` |

> **Note on Home Assistant Ingress**: this add-on does not use HA's built-in
> ingress panel for the MCP server. HA ingress authenticates the *browser* (via
> your HA session or a Home Assistant access token) but has no way to also
> supply the vault's own `mcp_auth_token`/OAuth credential to a downstream
> service — a remote MCP client can only send one `Authorization` header, and
> HA's own auth and this add-on's auth are deliberately separate secrets. Use
> `tunnel_mode: tailscale` or `https` for authenticated remote access instead.

#### Connecting Claude.ai

In Claude.ai → Settings → Integrations → Add MCP Server:

- **URL**: `http://<ha-ip>:8420/` (or your Tailscale/HTTPS URL)
- **Auth**: Bearer token or OAuth 2.1 depending on what you configured above

---

### Optional: reMarkable Cloud Sync

Set `enable_remarkable: true` to sync your reMarkable documents into your
Obsidian vault. This is a **one-way sync**: reMarkable → Obsidian.

#### Step 1: Register your device

The add-on always serves a registration UI at **`http://<your-ha-ip>:8421/`**.
You do not need `enable_remarkable: true` to use this page — registration is
always available so you can pair your device before enabling sync.

1. Open that URL in your browser
2. Enter the 8-character code from the step below and submit
3. The device token is saved to `/data/remarkable-sync/device.token` and reused
   across restarts

**To get your pairing code:**
- Go to `https://my.remarkable.com/device/desktop/new`
- Click the **Tablet** tab
- Copy the 8-character lowercase code shown (e.g. `xxxxxxxx`) — it expires in ~5 minutes

If no token is saved yet, the sync loop waits silently until one is provided —
no crash or restart loop. The saved token is stored as `remarkable_device_token`
internally; you can also set it explicitly in the add-on configuration to skip
the registration UI.

#### What gets synced

For each document on your reMarkable the sync engine creates:

- **`<vault>/reMarkable/<folder>/<Document Name>.md`** — a Markdown note with
  YAML front-matter (title, modified date, page count, tags, reMarkable ID)
  and a metadata table
- **`<vault>/reMarkable/<folder>/<Document Name>.pdf`** — the embedded PDF
  (for uploaded PDFs and annotated documents)
- **`<vault>/reMarkable/index.md`** — an index of all documents, updated on
  every sync

The full folder hierarchy from your reMarkable is preserved. Only documents
whose cloud version has changed are re-downloaded (cached in `/data/remarkable-sync/`).

#### Sync interval

Documents are checked every `remarkable_sync_interval` seconds (default: 300).
The vault sub-directory can be changed with `remarkable_output_dir` (default: `reMarkable`).

#### Optional: OCR for handwritten notebooks

Handwritten notebooks are synced as stub notes by default. To transcribe them,
point the add-on at a Home Assistant OCR endpoint:

| Option | Description |
|---|---|
| `ha_ocr_url` | Full URL to a HA webhook or REST endpoint that accepts `{"image": "<base64 PNG>"}` and returns `{"text": "..."}` |
| `ha_ocr_token` | Long-lived HA access token (not needed for unauthenticated webhooks) |
| `ha_ocr_entity` | Optional `image_processing` entity ID to include in the OCR payload |

Transcribed text appears under a `## Content (OCR)` section in the note,
with pages separated by `---`.

---

### Troubleshooting

| Symptom | Fix |
|---|---|
| Logs show `No Obsidian auth token found` | Open `http://<ha-ip>:8422/` and sign in — token is saved automatically |
| Logs show `vault_name is required` | Set `vault_name` in the add-on config |
| Sync fails with auth error | Token may have expired — re-run the token generator at port 8422 |
| `vault_password` error | Set `vault_password` if your vault uses E2E encryption |
| MCP server won't start | Set at least one of `mcp_auth_token` or `oauth_client_secret` |
| Config changes revert to defaults | Ensure `password` fields are either unset or contain a non-empty value |
| reMarkable registration returns HTTP 405 | Try a fresh pairing code — codes expire after ~5 minutes |

Full logs: **Settings → Add-ons → Obsidian Headless → Log**

---
### [Vector](https://github.com/conallob/hassio-addons/tree/master/vector)

**Version**: 0.56.0

High-performance observability data pipeline

### Overview

Vector is a high-performance observability data pipeline. Use it to collect,
transform, and route logs and metrics from your Home Assistant instance to any
destination.

Configuration is native Vector YAML, edited directly via the add-on's
**Configuration** tab (switch it to the raw YAML editor). The `vector_config`
option holds your pipeline's `sources:`, `transforms:`, and `sinks:` exactly
as documented on [vector.dev](https://vector.dev/docs/reference/configuration/)
— there's no separate structured UI translating a handful of add-on options
into Vector config, so anything Vector itself supports is available to you
directly, with no gaps.

The add-on ships with a working default `vector_config` (tails
`/config/home-assistant.log` to the console sink) so it runs out of the box;
edit it to build whatever pipeline you need.

For multiple, git-revisioned pipeline configs instead of the single embedded
`vector_config` option, see `config_mode` below.

---

### Options

#### Option: `config_mode`

Where Vector loads its pipeline from:

| Value | Behavior |
|-------|----------|
| `embedded` **(default)** | Build `/config/vector/vector.yaml` from `vector_config` (plus `api_enabled`/`syslog_enabled`), as described below. |
| `directory` | Start Vector with [`--config-dir`](https://vector.dev/docs/reference/cli/) pointed at `config_dir` instead — a directory of `*.yaml`/`*.toml`/`*.json` files that this add-on never writes to or generates. |

`directory` mode is for running Vector against a config directory you manage
yourself outside the add-on UI entirely — for example a git checkout under
`/share`, so you can track multiple pipeline revisions in git and switch
between them with `git checkout`/`git pull`, independent of the add-on. Vector
merges every recognized file directly inside that directory (not
subdirectories) into one config, same as it would with multiple `--config`
flags.

`vector_config`, `api_enabled`, and `syslog_enabled` are **ignored** in
`directory` mode — if you need Vector's API (for ingress) or a syslog source,
include that config in a file in the directory yourself.

Default: `embedded`

#### Option: `config_dir`

Filesystem path to the external config directory, used only when
`config_mode` is `directory`. Must be under a mapped volume — `/share/...` or
`/config/...` — since those are the only paths the container can see; a git
checkout under `/share` (e.g. `/share/vector-config`) is the typical setup.

Default: `""` (required when `config_mode` is `directory`)

#### Option: `vector_config`

Only used when `config_mode` is `embedded` (the default). Your Vector
pipeline, in native Vector YAML — `sources:`, `transforms:`, and `sinks:`.
See:

- [Sources](https://vector.dev/docs/reference/configuration/sources/)
- [Transforms](https://vector.dev/docs/reference/configuration/transforms/)
  (including [VRL](https://vector.dev/docs/reference/vrl/) via the `remap` transform)
- [Sinks](https://vector.dev/docs/reference/configuration/sinks/)

Do **not** declare a top-level `api:` key here — that's managed separately via
`api_enabled` (see below), since the add-on's ingress panel depends on it
being set to a specific address.

Example — tail Home Assistant's log and forward to Loki:

```yaml
sources:
  ha_logs:
    type: file
    include:
      - /config/home-assistant.log
    read_from: beginning

sinks:
  loki:
    type: loki
    inputs:
      - ha_logs
    endpoint: "http://192.168.1.100:3100"
    labels:
      job: home_assistant
    encoding:
      codec: json
```

Example — remote syslog server on the standard port, using `syslog_enabled`
(see below) instead of hand-writing the source. With `syslog_enabled: true`,
this `vector_config` is all you need:

```yaml
sinks:
  console:
    type: console
    inputs:
      - syslog_tcp
      - syslog_udp
    target: stdout
    encoding:
      codec: json
```

If you'd rather write the syslog source yourself — a non-standard port, for
example — `6000/tcp` and `6000/udp` are pre-mapped for that:

```yaml
sources:
  syslog_in:
    type: syslog
    mode: tcp
    address: "0.0.0.0:6000"
```

`9000/tcp` is likewise pre-mapped for a Vector-to-Vector source. Reuse any of
these ports, remap them to something else in the add-on's Network settings,
or, if you need a port that isn't pre-mapped at all, add it to this add-on's
`config.yaml` and rebuild.

If your pipeline needs a credentials file that can't be embedded inline (e.g.
a GCP service account JSON key for the `gcp_stackdriver_logs` sink), place it
under `/share` or `/config` (both read-write mapped into the container — use
the Samba or File editor add-on) and point `credentials_path` at it directly.

Default: a working pipeline — HA log file → console sink (see `config.yaml`).

#### Option: `api_enabled`

Whether the add-on injects the `api:` block Vector needs for the ingress
panel (and direct external access on port 8686) to work. Leave this on unless
you have a specific reason to disable Vector's API.

Default: `true`

#### Option: `syslog_enabled`

Turn Vector into a standard remote syslog server with no source YAML to
write: adds `syslog_tcp` and `syslog_udp` sources listening on the standard
syslog port **514** (already mapped in the add-on's Network settings) into
your `sources:` block — or adds a `sources:` block for you if `vector_config`
doesn't have one. Point your devices' syslog destination at the Home
Assistant host, port 514, enable this option, and reference `syslog_tcp` /
`syslog_udp` as inputs on whatever sink you want the data to reach.

This only *adds* those two sources; it doesn't wire them into a sink for
you, since sink choice is entirely yours. See the `vector_config` example
above.

Default: `false` (disabled)

#### Option: `log_level`

Add-on log verbosity. Possible values: `trace`, `debug`, `info`, `notice`,
`warning`, `error`, `fatal`.

Default: `info`

---

### Ports

| Port | Purpose |
|------|---------|
| 8686 | Vector API (when `api_enabled: true`) |
| 514/tcp, 514/udp | Standard syslog server (when `syslog_enabled: true`) |
| 6000/tcp, 6000/udp | Available for a syslog source on a custom port, if defined in `vector_config` |
| 9000/tcp | Available for a Vector-to-Vector source, if defined in `vector_config` |

These are pre-declared so they can be mapped from the add-on's Network
settings; whether they're actually listened on depends on `syslog_enabled`
(for 514) or on whether your `vector_config` defines a source bound to them
(for the others).

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
