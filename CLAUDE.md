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

- **Version**: 0.56.0, tracking upstream Vector releases directly (https://github.com/vectordotdev/vector/releases).
- **Base image**: `ghcr.io/home-assistant/{arch}-base-debian:bookworm`, s6-overlay, Vector binary copied in from `timberio/vector:${VECTOR_VERSION}-debian` in a multi-stage build.
- **Distribution**: `config.yaml` declares `image: "ghcr.io/conallob/vector-{arch}"` — this repo's CI (`build.yml`) builds and pushes that image on every merge to `main`, so Supervisor pulls a prebuilt image and offers normal Updates (gated on the `version` field changing) instead of only building from source on-device.
- **Configuration**: minimal by design — only `log_level` and `api_enabled` are structured add-on options. The actual pipeline (`sources:`/`transforms:`/`sinks:`) is written directly in native Vector YAML via the `vector_config` option (edited through the add-on's raw YAML config editor), so anything Vector itself supports is available with no translation layer. Ports `514/tcp+udp`, `6000/tcp+udp`, and `9000/tcp` are pre-mapped in `config.yaml` for common source ports (syslog standard/custom, Vector-to-Vector); a pipeline can bind any of them without further add-on changes.
- **Known issues**: none currently tracked.

### alloy (`alloy/`)

- **Purpose**: Grafana Alloy observability pipeline, configurable to collect:
  - Home Assistant Prometheus metrics (scrape `http://supervisor/core/api/prometheus` with HA token)
  - Home Assistant log forwarding (loki-compatible output)
  - Both simultaneously
- **Status**: Implemented — Dockerfile, s6-overlay service, and init script (`alloy/rootfs/etc/cont-init.d/alloy.sh`) generating config from add-on options are in place.

---

## Workflow

- Always use the `github-pr` agent when creating PRs for this repo.
- Always use the `lint-test` agent before committing.
- Always use the `spell-check` agent before committing.
- Include the original prompt as a markdown code block in PR descriptions.
