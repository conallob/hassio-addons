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
- Cloudprober reads its config at start-up. After a `git pull`, **restart the
  add-on** to pick up changes.

At least one of `cloudprober_config` and `extra_config_path` must be non-empty.

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

## Ports

| Port | Purpose |
|------|---------|
| 9313/tcp | Status page and Prometheus metrics (`/metrics`). Used by the ingress panel; unmapped to the host by default. |

Probes that use ICMP or raw sockets may need extra privileges that this add-on
does not request; HTTP, TCP and DNS probes work without them.
