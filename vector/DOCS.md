# Home Assistant Add-on: Vector

## Overview

Vector is a high-performance observability data pipeline that puts you in
control of your data. Use it to collect, transform, and route logs and metrics
from your Home Assistant instance to any destination.

## Installation

1. Navigate in your Home Assistant frontend to **Settings** → **Add-ons** →
   **Add-on Store**.
2. Click the three-dot menu at upper right → **Repositories** and add this
   repository URL: `https://github.com/conallob/hassio-addons`
3. Find the "Vector" add-on and click it.
4. Click **INSTALL**.

## Configuration

All configuration is done through the add-on UI in Home Assistant.

**Remember to restart the add-on when the configuration is changed.**

### Option: `log_level`

Controls the verbosity of add-on logging. Possible values:

- `trace` — Show every detail, like all called internal functions.
- `debug` — Detailed debug information.
- `info` — Normal (usually) interesting events. **(default)**
- `notice` — Normal but significant events.
- `warning` — Exceptional occurrences that are not errors.
- `error` — Runtime errors that do not require immediate action.
- `fatal` — Something went terribly wrong. Add-on becomes unusable.

Each level automatically includes messages from more severe levels.

### Option: `api_enabled`

Toggle the Vector API on or off. When enabled, the Vector GraphQL API is
available on port **8686**. This is useful for monitoring Vector's health and
performance.

Default: `true`

### Option: `vector_config`

The Vector pipeline configuration in YAML format. This is where you define your
**sources**, **transforms**, and **sinks**. The API section is managed
separately via the `api_enabled` toggle — you only need to provide the pipeline
definition here.

Default configuration collects host metrics and prints them to the add-on log:

```yaml
sources:
  host_metrics:
    type: host_metrics
    filesystem:
      devices:
        excludes: ["binfmt_misc"]

sinks:
  console:
    inputs:
      - host_metrics
    target: stdout
    type: console
    encoding:
      codec: json
```

## Example Configurations

### Collect Home Assistant Logs

```yaml
sources:
  home_assistant_logs:
    type: file
    include:
      - /config/home-assistant.log
    read_from: end

sinks:
  console:
    inputs:
      - home_assistant_logs
    target: stdout
    type: console
    encoding:
      codec: json
```

### Forward to Loki (Grafana)

```yaml
sources:
  host_metrics:
    type: host_metrics

sinks:
  loki:
    type: loki
    inputs:
      - host_metrics
    endpoint: http://your-loki-host:3100
    labels:
      source: vector
      host: homeassistant
    encoding:
      codec: json
```

### Syslog Receiver

If you want Vector to receive syslog messages from other devices on your
network, expose an additional port in the add-on network configuration
first, then add:

```yaml
sources:
  syslog:
    type: syslog
    address: 0.0.0.0:5514
    mode: tcp

sinks:
  console:
    inputs:
      - syslog
    target: stdout
    type: console
    encoding:
      codec: json
```

## Mapped Volumes

The add-on has access to the following Home Assistant directories:

| Path      | Access     | Description                        |
|-----------|------------|------------------------------------|
| `/config` | read-write | Home Assistant configuration files |
| `/share`  | read-write | Shared storage between add-ons     |
| `/ssl`    | read-only  | SSL certificates                   |

## Vector Documentation

For the full list of available sources, transforms, and sinks, see the
[Vector documentation](https://vector.dev/docs/).

## Support

Open an issue on GitHub:
<https://github.com/conallob/hassio-addons/issues>
