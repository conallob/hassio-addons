# Home Assistant Add-on: Vector

## Overview

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

## Options

### Option: `config_mode`

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

Switching to `directory` mode also actively clears `vector_config` (via the
Supervisor API) rather than leaving whatever pipeline was there before the
switch sitting around unused — it won't keep tracking a stale embedded
config once it's no longer in effect. Switching back to `embedded` later
means re-entering it.

Default: `embedded`

### Option: `config_dir`

Filesystem path to the external config directory, used only when
`config_mode` is `directory`. Must be under a mapped volume — `/share/...` or
`/config/...` — since those are the only paths the container can see; a git
checkout under `/share` (e.g. `/share/vector-config`) is the typical setup.

Default: `""` (required when `config_mode` is `directory`)

### Option: `vector_config`

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

### Option: `api_enabled`

Whether the add-on injects the `api:` block Vector needs for the ingress
panel (and direct external access on port 8686) to work. Leave this on unless
you have a specific reason to disable Vector's API.

Default: `true`

### Option: `syslog_enabled`

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

### Option: `log_level`

Add-on log verbosity. Possible values: `trace`, `debug`, `info`, `notice`,
`warning`, `error`, `fatal`.

Default: `info`

---

## Ports

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
