# Conall's Home Assistant Add-ons

My personal collection of add-ons for [Home Assistant](https://www.home-assistant.io/).

## Installation

Add this repository to your Home Assistant add-on store:

[![Add repository](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fconallob%2Fhassio-addons)

Or manually: **Settings → Add-ons → Add-on Store → ⋮ → Repositories** and add `https://github.com/conallob/hassio-addons`.

---

## Add-ons

### [ntfy](./ntfy)

Self-hosted push notification server ([ntfy.sh](https://ntfy.sh)). Accessible
directly from the Home Assistant sidebar via ingress. Supports optional HTTPS
using certificates issued by the Home Assistant Let's Encrypt add-on.

**Features:**
- Home Assistant ingress (sidebar access, no port forwarding required)
- Optional HTTPS via the HA Let's Encrypt add-on
- Persistent message cache, user database, and attachments
- iOS push notification relay via ntfy.sh upstream

---

### [Vector](./vector)

High-performance observability data pipeline ([vector.dev](https://vector.dev)).
Collect, transform, and route logs from Home Assistant to any destination —
configured entirely from the Home Assistant UI.

**Features:**
- Tail Home Assistant logs with optional VRL transforms
- Syslog TCP/UDP listener (receive logs from other devices on your network)
- Vector-to-Vector source (aggregate from remote Vector agents)
- Sinks: console, Loki, Elasticsearch, HTTP, GCP Cloud Logging
- GCP credentials managed via the add-on UI (no SSH required)
- Vector API on port 8686
- Raw Vector YAML override for advanced pipelines

---

### [Grafana Alloy](./alloy)

OpenTelemetry-compatible observability collector ([Grafana Alloy](https://grafana.com/oss/alloy-opentelemetry-collector/)).
Scrape Home Assistant Prometheus metrics and/or forward logs to Loki,
configured from the Home Assistant UI.

**Features:**
- Scrape the Home Assistant Prometheus endpoint (authenticated automatically via Supervisor token)
- Forward Home Assistant logs to any Loki-compatible endpoint
- Remote-write metrics to Grafana Cloud, Mimir, or a local Prometheus
- Custom Alloy River config override for advanced pipelines
- Alloy UI on port 12345
