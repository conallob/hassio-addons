# Home Assistant Add-on: Cloudprober

## Overview

[Cloudprober](https://cloudprober.org) runs synthetic probes (HTTP, ping, DNS,
TCP, external scripts and more) and exposes the results as Prometheus metrics.
The status page is available from the Home Assistant sidebar (ingress), and
metrics are served at `/metrics` on port 9313.

Configuration is native Cloudprober config (textproto), documented at
[cloudprober.org/docs/config](https://cloudprober.org/docs/config/overview/).
The add-on ships with a working default (one HTTP probe of Home Assistant plus a
Prometheus surfacer) so it runs out of the box.

---

## Options

### Option: `cloudprober_config`

The main Cloudprober config, in textproto format, used verbatim. Edit it in the
add-on's raw YAML editor as a multi-line string.

### Option: `extra_config_path`

An additional config file (or glob) to include, **relative to
`/homeassistant`** (your HA config directory), for example
`cloudprober/extra.cfg` or `cloudprober/*.cfg`. A leading `/homeassistant/` is
also accepted. Leave empty to disable.

This is intended for a git-managed checkout:

```
/homeassistant/cloudprober/
    probes.cfg        # probe { ... } blocks
```

With `extra_config_path: "cloudprober/probes.cfg"` the add-on appends
`include "<relative path>"` to the generated main config, so Cloudprober loads
the file as if its contents were written inline.

Things to know:

- The file must be **textproto** (`.cfg`), the same format as
  `cloudprober_config`. The include is textual, so YAML or JSON files cannot be
  included.
- Repeated blocks such as `probe { ... }` and `surfacer { ... }` merge from both
  sources, but probe names must be unique across them. The default
  `cloudprober_config` already declares a `PROMETHEUS` surfacer, so don't add
  another in the extra file.
- The add-on refuses to start if `extra_config_path` matches no files or points
  outside `/homeassistant`, naming the path in the log.
- The `/homeassistant` mount is read-only.
- The generated config, including the extra file, is validated with
  `cloudprober -configtest` on every start; the add-on refuses to start and logs
  Cloudprober's error if it fails. Home Assistant has no on-save hook for
  add-ons, so saving options alone doesn't trigger this: restart to apply and
  validate.
- Cloudprober reads its config at start-up. After a `git pull`, **restart the
  add-on** to pick up changes.

To validate the file in CI on the git repo itself, the same check works
standalone (the extra file must be valid on its own):

```bash
cloudprober --config_file cloudprober/probes.cfg -configtest
```

At least one of `cloudprober_config` and `extra_config_path` must be non-empty.

### Option: `grpc_enabled`

Start Cloudprober's **default gRPC server** (its own API) on port 9314 (default:
off). Cloudprober has no built-in port for this, so the add-on sets
`CLOUDPROBER_GRPC_PORT=9314` when it is on. A `grpc_port` set in your own config
takes precedence over this option; the add-on logs a notice, and a warning if it
isn't 9314, since that port can't then be published from the add-on's Network
settings. This is separate from the built-in `GRPC` server below, which is
enabled by config alone.

### Option: `env_vars`

A list of environment variables to set for Cloudprober, as `name`/`value`
pairs. Use it for anything Cloudprober reads from the environment, for example
global metric labels:

```yaml
env_vars:
  - name: CLOUDPROBER_ADDITIONAL_LABELS
    value: "site=home,env=prod"
```

`CLOUDPROBER_ADDITIONAL_LABELS` takes comma-separated `key=value` pairs that are
added to every metric (existing probe labels win). See
[Additional labels](https://cloudprober.org/docs/how-to/additional-labels/).

Variables are also available to your config: Cloudprober replaces `**$NAME**` in
the config text with the variable's value, which keeps site-specific values out
of a shared, git-managed config file.

Things to know:

- Names must be valid shell identifiers. Names the add-on manages
  (`CLOUDPROBER_PORT`, `SUPERVISOR_TOKEN`, `HASSIO_TOKEN`, `PATH`,
  `LD_PRELOAD`, `LD_LIBRARY_PATH`, anything starting `S6_`) are rejected and the
  add-on refuses to start.
- `CLOUDPROBER_GRPC_PORT` is set by `grpc_enabled`; if both are used,
  `grpc_enabled` wins.
- Values are stored in the add-on's options and are visible to anyone who can
  view its configuration, so don't treat this as secret storage. Startup logs
  list variable names, never values.
- Variables apply at start-up; restart the add-on after changing them.

### Option: `log_level`

Verbosity of the add-on's own startup logging.

---

## Example

`cloudprober_config`:

```
surfacer {
  type: PROMETHEUS
}
```

`extra_config_path`: `cloudprober/probes.cfg`

`/homeassistant/cloudprober/probes.cfg`:

```
probe {
  name: "router"
  type: PING
  targets {
    host_names: "192.168.1.1"
  }
  interval_msec: 10000
  timeout_msec: 2000
}
```

## Built-in servers

Cloudprober can also run [built-in servers](https://cloudprober.org/docs/how-to/built-in-servers/)
that act as probe targets, for example for a second Cloudprober instance to
probe. They are enabled by adding `server { ... }` blocks to
`cloudprober_config` or your extra config file:

```
server {
  type: HTTP
  http_server {
    port: 3141
  }
}
```

The servers bind inside the add-on regardless, so other add-ons and Home
Assistant can reach them on the internal network. To reach one from elsewhere
on your network, set a host port for it in the add-on's **Network** settings.
Home Assistant can only publish ports the add-on declares, so use the default
ports below.

| Server | Block | Default port |
|--------|-------|--------------|
| HTTP (`/healthcheck`, `/lameduck`, data handlers) | `type: HTTP` | 3141/tcp |
| gRPC (probe target) | `type: GRPC` | 3142/tcp |
| UDP (echo/discard) | `type: UDP` | none — `port` is required; UDP ports are **not** declared, so these are reachable only from inside Home Assistant's network |

## Ports

| Port | Purpose |
|------|---------|
| 9313/tcp | Status page and Prometheus metrics (`/metrics`). Used by the ingress panel; unmapped to the host by default. |
| 9314/tcp | Default gRPC server (API), only when `grpc_enabled` is true; unmapped to the host by default. |
| 3141/tcp | Built-in HTTP server, only if configured with `server { type: HTTP }`; unmapped by default. |
| 3142/tcp | Built-in gRPC server, only if configured with `server { type: GRPC }`; unmapped by default. |

Probes that use ICMP or raw sockets may need extra privileges that this add-on
does not request; HTTP, TCP and DNS probes work without them.
