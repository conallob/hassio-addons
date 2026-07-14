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

---

## Options

### Option: `vector_config`

Your Vector pipeline, in native Vector YAML — `sources:`, `transforms:`, and
`sinks:`. See:

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

Example — remote syslog server on the standard port. `514/tcp` and `514/udp`
are already mapped in the add-on's Network settings, so this needs no other
setup beyond pointing your devices at the Home Assistant host, port 514:

```yaml
sources:
  syslog_in:
    type: syslog
    mode: tcp
    address: "0.0.0.0:514"

sinks:
  console:
    type: console
    inputs:
      - syslog_in
    target: stdout
    encoding:
      codec: json
```

`6000/tcp`, `6000/udp`, and `9000/tcp` are also pre-mapped for a custom-port
syslog source or a Vector-to-Vector source, respectively — reuse them, remap
them to something else in the add-on's Network settings, or, if you need a
port that isn't pre-mapped at all, add it to this add-on's `config.yaml` and
rebuild.

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

### Option: `log_level`

Add-on log verbosity. Possible values: `trace`, `debug`, `info`, `notice`,
`warning`, `error`, `fatal`.

Default: `info`

---

## Ports

| Port | Purpose |
|------|---------|
| 8686 | Vector API (when `api_enabled: true`) |
| 514/tcp, 514/udp | Available for a syslog source on the standard port |
| 6000/tcp, 6000/udp | Available for a syslog source on a custom port |
| 9000/tcp | Available for a Vector-to-Vector source |

These are pre-declared so they can be mapped from the add-on's Network
settings; whether they're actually listened on depends entirely on whether
your `vector_config` defines a source bound to them.

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
