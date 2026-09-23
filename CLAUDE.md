# hassio-addons — Claude Code Instructions

This repository contains custom Home Assistant add-ons maintained by Conall O'Brien.

## Repository Structure

```
hassio-addons/
├── repository.json          # Add-on store metadata
├── ntfy/                    # ntfy push notification server
└── vector/                  # Vector observability pipeline
```

## Add-on Development Conventions

### Base Images

All add-ons **must** use the official Home Assistant base images via `BUILD_FROM` ARG:

```dockerfile
ARG BUILD_FROM
FROM ${BUILD_FROM}
```

Available bases (from `ghcr.io/home-assistant/`):
- `aarch64-base-debian:bookworm` / `amd64-base-debian:bookworm` — Debian with s6-overlay
- `aarch64-base:latest` / `amd64-base:latest` — Alpine with s6-overlay

Third-party images (e.g. `timberio/vector`, `binwiederhier/ntfy`) must **not** be used as the base; instead copy binaries from them in a multi-stage build.

### s6-overlay Init System

Home Assistant add-ons use [s6-overlay v3](https://github.com/just-containers/s6-overlay) for process supervision. Services live in:

```
rootfs/etc/s6-overlay/s6-rc.d/<service-name>/
    run     # executable service script (longrun) or oneshot script
    type    # file containing "longrun" or "oneshot"
```

A `user/contents.d/<service-name>` empty file registers the service with the bundle.

### Initialization Scripts

One-time init runs from `rootfs/etc/cont-init.d/*.sh` (alphabetical order). Use `bashio` helpers:

```bash
#!/usr/bin/with-contenv bashio
value=$(bashio::config 'option_name')
bashio::log.info "message"
bashio::log.fatal "message"
bashio::exit.nok   # exits with failure
```

### config.yaml Required Fields

| Field | Notes |
|-------|-------|
| `name` | Display name |
| `version` | Must match binary/image version |
| `slug` | Unique identifier, lowercase |
| `init: false` | Always set — HA does not use legacy init |
| `arch` | List: `aarch64`, `amd64` |
| `startup` | Typically `services` |
| `map` | Volume mounts: `config:rw`, `ssl:ro`, `share:rw` |

### Ingress

To expose a web UI through the HA sidebar:

```yaml
ingress: true
ingress_port: <port>  # port the service listens on inside the container
```

The service must listen on `0.0.0.0:<ingress_port>` (not `127.0.0.1`). HA proxies requests with a path prefix; the service must handle this correctly (use `behind-proxy: true` or equivalent).

Do **not** map ports 80 or 443 if the service does not actively use them — HA may have its own listeners on those ports.

---

## Add-on Status

### ntfy (`ntfy/`)

- **Version**: 2.11.0
- **Binary source**: `binwiederhier/ntfy:v2.11.0` (multi-stage copy)
- **Base image**: `ghcr.io/home-assistant/aarch64-base-debian:bookworm`
- **Ingress port**: 2586
- **Known issue**: HTTP 502 on WebUI — likely caused by ntfy not receiving the correct ingress base path or `base-url` not being set, causing asset/redirect failures through the HA ingress proxy. The `behind-proxy: true` flag is set but ntfy also needs the `base-url` to match the full ingress URL for the web UI to load correctly. Investigate setting `base-url` dynamically from `bashio::addon.ingress_url`.
- **Optional external ports**: 80 (ACME), 443 (HTTPS) — only needed when Let's Encrypt or manual SSL is configured.

### vector (`vector/`)

- **Version**: 0.57.0, tracking upstream Vector releases directly (https://github.com/vectordotdev/vector/releases).
- **Base image**: `ghcr.io/home-assistant/{arch}-base-debian:bookworm`, s6-overlay, Vector binary copied in from `timberio/vector:${VECTOR_VERSION}-debian` in a multi-stage build.
- **Distribution**: `config.yaml` declares `image: "ghcr.io/conallob/vector-{arch}"` — this repo's CI (`build.yml`) builds and pushes that image on every merge to `main`, so Supervisor pulls a prebuilt image and offers normal Updates (gated on the `version` field changing) instead of only building from source on-device.
- **Configuration**: minimal by design — only `log_level`, `api_enabled`, `syslog_enabled`, `config_mode`, and `config_dir` are structured add-on options. The actual pipeline (`sources:`/`transforms:`/`sinks:`) is written directly in native Vector YAML via the `vector_config` option (edited through the add-on's raw YAML config editor), so anything Vector itself supports is available with no translation layer. `syslog_enabled` is the one convenience exception: it merges `syslog_tcp`/`syslog_udp` source entries (port 514) into whatever `sources:` block is in `vector_config`, since hand-writing a syslog source is the one piece of boilerplate common enough to justify a toggle — the user still wires those source IDs into a sink themselves. Ports `514/tcp+udp`, `6000/tcp+udp`, and `9000/tcp` are pre-mapped in `config.yaml` for common source ports (syslog standard/custom, Vector-to-Vector); a pipeline can bind any of them without further add-on changes.
- **`config_mode`**: `embedded` (default, described above) or `directory`, which starts Vector with `--config-dir` against `config_dir` (e.g. a git-managed checkout under `/share`) instead of generating `vector.yaml` at all — lets multiple pipeline revisions be tracked in git and swapped independently of the add-on. `vector_config`/`api_enabled`/`syslog_enabled` are ignored in this mode; the run script (`rootfs/etc/s6-overlay/s6-rc.d/vector/run`) picks `--config` vs `--config-dir` based on it, and `vector.sh` skips config generation entirely when it's `directory`. It also actively clears `vector_config` via the Supervisor API (`POST /addons/self/options`) when switching into `directory` mode, so it doesn't keep tracking a stale embedded pipeline while unused.
- **Known issues**: none currently tracked.

### alloy (`alloy/`)

- **Purpose**: Grafana Alloy observability pipeline, configurable to collect:
  - Home Assistant Prometheus metrics (scrape `http://supervisor/core/api/prometheus` with HA token)
  - Home Assistant log forwarding (loki-compatible output)
  - Both simultaneously
- **Status**: Implemented — Dockerfile, s6-overlay service, and init script (`alloy/rootfs/etc/cont-init.d/alloy.sh`) generating config from add-on options are in place.

### calibre-web-automated (`calibre-web-automated/`)

- **Version**: 4.0.6, tracking upstream Calibre-Web Automated releases one-to-one (https://github.com/crocodilestick/Calibre-Web-Automated/releases) — `config.yaml`'s `version` is always the CWA release bundled; bump it and `build.yaml`'s `CWA_VERSION` (the exact upstream git tag) together.
- **Base image**: `ghcr.io/home-assistant/{arch}-base-debian:bookworm`, s6-overlay. Unlike ntfy/vector, this isn't a single binary copied from a third-party image — CWA's own source, Calibre, and kepubify are each fetched from their original upstream sources (GitHub tag tarball, calibre-ebook.com release, kepubify GitHub release) and built directly on the HA base, since upstream's own image is built on `ghcr.io/linuxserver/baseimage-ubuntu` rather than a single portable binary.
- **s6 services**: reuses CWA's own `s6-rc.d` service tree (`cwa-init`, `svc-calibre-web-automated`, `cwa-ingest-service`, `metadata-change-detector`, `cwa-auto-library`, `cwa-auto-zipper`, `cwa-checksum-backfill`, `cwa-process-recovery`, `calibre-binaries-setup`) copied in from upstream almost unmodified, with the linuxserver-only `init-config`/`init-adduser` dependency links (which don't exist on the HA base) stripped out. `cwa-ingress-proxy` (this add-on's own, added on top) runs a small `nginx-light` reverse proxy dedicated to ingress traffic — see Ingress below.
- **Configuration**: minimal by design, matching CWA's own philosophy of managing everything else through its own web UI/database once running. `library_dir` and `ingest_dir` (both relative to `/share`) are the only paths a user needs to set; `network_share_mode` switches the ingest watcher and metadata change detector to polling instead of `inotify` when `/share` is itself a network mount.
- **Ingress**: CWA (Flask) generates root-absolute links (`/static/...`, redirects to `/`), and Supervisor's ingress proxy strips the `/api/hassio_ingress/<token>` prefix before forwarding to the add-on without sending any header identifying it (no `X-Ingress-Path`/`X-Forwarded-Prefix`/`X-Forwarded-Host`) — those links then escape the ingress iframe and 404 against Home Assistant's own frontend router. CWA's `ReverseProxied` middleware fixes this given the prefix via `X-Script-Name`, so `config.yaml`'s `ingress_port` (8084) points at a dedicated `nginx-light` proxy (`cwa-ingress-proxy` service, config templated by `rootfs/etc/cont-init.d/calibre-web-automated-ingress.sh` from `rootfs/etc/nginx/cwa-ingress.conf.template`, using `bashio::app.ingress_entry`) that injects `X-Script-Name` and forwards to CWA's own server on 8083 — the same port still used, unchanged, for direct (non-ingress) access via `ports:`.
- **Known issues**: this is a best-effort initial port — it has not been build- or run-verified against a live Supervisor install (no Docker daemon was available when authoring it). Full RAR5 extraction requires the proprietary `unrar` binary, which isn't packaged for Debian; the build falls back to `unrar-free` (RAR3-era support only) when available.

### omnifocus-sync-mcp (`omnifocus-sync-mcp/`)

- **Purpose**: HTTP interface to [`rosskukulinski/omnifocus-sync-mcp`](https://github.com/rosskukulinski/omnifocus-sync-mcp), a headless MCP server that reads/writes OmniFocus tasks by talking to Omni Sync Server directly over WebDAV (client-side end-to-end decryption) — no Mac or OmniFocus app needed, only Omni Sync Server credentials.
- **Version**: 0.4.0 — this add-on's own version, independent of upstream (upstream still has no tagged releases; its `package.json` is still `0.1.0`). Supervisor caches locally-built add-on images by this `version`, so bump it on every change to this add-on's own files (Dockerfile, rootfs, `OMNIFOCUS_SYNC_MCP_REF`) even when upstream hasn't moved, or Supervisor can silently reuse a stale cached build.
- **Base image**: `ghcr.io/home-assistant/{arch}-base-debian:bookworm`, s6-overlay. Upstream ships no Dockerfile — the build clones its source at the commit pinned in `build.yaml`'s `OMNIFOCUS_SYNC_MCP_REF` (a SHA, not a moving branch ref — see that file for how to update it) in a `node:20-bookworm-slim` builder stage, runs `npm run build`, then copies `dist/`/`node_modules`/`package.json` onto the HA base, which itself gets a NodeSource Node.js 20 runtime installed via `apt` (not present on the HA base image) alongside `supergateway`. `curl` must stay installed after that (see Dockerfile comment) — bashio needs it for every Supervisor API call.
- **Transport bridge**: upstream only implements MCP's stdio transport; `supergateway` (`npm install -g supergateway`) wraps `node dist/index.js` and re-exposes it as streamable HTTP on `127.0.0.1:8643/mcp` (loopback-only — see `rootfs/etc/s6-overlay/s6-rc.d/omnifocus-sync-mcp/run`), since `supergateway` has no incoming-request auth of its own.
- **Auth proxy**: a second s6 service, `omnifocus-sync-mcp-auth-proxy` (`rootfs/etc/s6-overlay/s6-rc.d/omnifocus-sync-mcp-auth-proxy/run` + `rootfs/opt/auth-proxy/auth-proxy.mjs`), is the actual public/ingress-facing listener on `:8642` (bind address configurable — see `listen_address` below) — both the ingress panel and direct network MCP clients hit it. It's a small Node script (`http-proxy`, installed via `npm install --prefix /opt/auth-proxy` in the Dockerfile) that enforces `auth_mode` (`bearer`, static-token check via `crypto.timingSafeEqual`; `oauth2_introspection`, RFC 7662 token introspection against `oauth2_introspection_url`; or `none`) and only then forwards to `supergateway` on `127.0.0.1:8643`.
- **Configuration**: `sync_username`/`sync_password` (required, map to `OMNIFOCUS_SYNC_USERNAME`/`OMNIFOCUS_SYNC_PASSWORD`) plus optional `encryption_passphrase`, `sync_url`, `database`, `client_name`, and a `read_only` toggle (`OMNIFOCUS_READ_ONLY=1`) — one-to-one with upstream's own env vars (see its `.env.example`). Sync client state persists at `/data/omnifocus-sync-mcp/client.json`, under the add-on's own `/data` so no `/config` or `/share` mapping is needed. `auth_mode` (default `bearer`), `bearer_token`, `oauth2_introspection_url`, and `oauth2_introspection_auth_header` configure the auth proxy above; both `run` scripts fail fast (`bashio::exit.nok`) if a mode's required option is missing. `listen_address` (default `0.0.0.0`, plumbed to the auth proxy as `LISTEN_HOST`) controls which address the `:8642` proxy binds to inside the container — for running your own reverse proxy/ingress in front instead of Supervisor's, or restricting exposure on a multi-homed host; setting it to `127.0.0.1` breaks the HA ingress panel, since ingress connects over the container's internal Docker network address, never loopback (documented in `DOCS.md`). `auth-proxy.mjs`'s `parseListenHost()` accepts (and warns then discards the port from) a `host:port`/`[ipv6]:port` value too, since the internal container port is fixed at `8642` by `config.yaml` and can't actually be changed here — passing an unparsed `"ip:port"` string straight to `server.listen()` previously crash-looped with `getaddrinfo ENOTFOUND`; use this add-on's Network settings in HA to remap the external/host port instead.
- **Known issues**: this is a best-effort initial port — it has not been build- or run-verified against a live Supervisor install (no Docker daemon was available when authoring it), and the auth proxy's behavior through the HA ingress path prefix is unconfirmed; if ingress doesn't work, try connecting an MCP client directly to `:8642/mcp` (with `auth_mode` credentials) first to narrow down the issue.

---

## Workflow

- Always use the `github-pr` agent when creating PRs for this repo.
- Always use the `lint-test` agent before committing.
- Always use the `spell-check` agent before committing.
- Include the original prompt as a markdown code block in PR descriptions.
