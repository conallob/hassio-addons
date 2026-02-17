# ntfy - Home Assistant Add-on

Self-hosted push notification server ([ntfy.sh](https://ntfy.sh)) with Home Assistant ingress support and optional Let's Encrypt SSL certificate management.

## Features

- **Home Assistant Ingress**: Access the ntfy web UI directly from the Home Assistant sidebar
- **Let's Encrypt SSL**: Automated certificate acquisition and renewal via built-in certbot
- **Manual SSL**: Use your own certificates (e.g. from the HA Let's Encrypt add-on)
- **Persistent storage**: Message cache, user database, and attachments survive restarts
- **iOS push support**: Upstream relay to ntfy.sh for instant iOS notifications

## Installation

1. Add this repository to your Home Assistant add-on store
2. Install the **ntfy** add-on
3. Configure the add-on options (see below)
4. Start the add-on

## Configuration

### Minimal (ingress only, no external access)

No configuration needed. Start the add-on and access ntfy through the Home Assistant sidebar.

### With Let's Encrypt (recommended for external access)

```yaml
domain: "ntfy.example.com"
ssl: false
letsencrypt: true
letsencrypt_email: "you@example.com"
auth_default_access: "deny-all"
```

Ensure port 80 is forwarded to your Home Assistant host for ACME HTTP-01 challenges, and port 443 for the ntfy HTTPS API.

### With existing SSL certificates

```yaml
domain: "ntfy.example.com"
ssl: true
certfile: "fullchain.pem"
keyfile: "privkey.pem"
auth_default_access: "deny-all"
```

Place your certificates in the Home Assistant `/ssl/` directory (e.g. managed by the HA Let's Encrypt add-on).

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `domain` | `""` | Public domain name for external access |
| `ssl` | `false` | Enable HTTPS using certificates from `/ssl/` |
| `certfile` | `fullchain.pem` | SSL certificate filename (relative to `/ssl/`) |
| `keyfile` | `privkey.pem` | SSL private key filename (relative to `/ssl/`) |
| `letsencrypt` | `false` | Enable automatic Let's Encrypt certificate management |
| `letsencrypt_email` | `""` | Email for Let's Encrypt registration |
| `auth_default_access` | `read-write` | Default access: `read-write`, `read-only`, `write-only`, `deny-all` |
| `upstream_base_url` | `https://ntfy.sh` | Upstream server for iOS push notifications |
| `log_level` | `info` | Log verbosity: `trace`, `debug`, `info`, `warn`, `error` |

## Ports

| Port | Purpose |
|------|---------|
| 443 | ntfy HTTPS API (external access, requires SSL) |
| 80 | HTTP / Let's Encrypt ACME challenges |

## Usage

### Send a notification

```bash
curl -d "Hello from Home Assistant" https://ntfy.example.com/my-topic
```

### Subscribe in the ntfy app

Point the ntfy Android/iOS app at `https://ntfy.example.com` and subscribe to your topics.

### Home Assistant automations

Use the [REST command](https://www.home-assistant.io/integrations/rest_command/) integration:

```yaml
rest_command:
  ntfy_notify:
    url: "https://ntfy.example.com/my-topic"
    method: POST
    content_type: "application/json"
    payload: '{"message": "{{ message }}", "title": "{{ title }}"}'
```

## More information

- [ntfy documentation](https://docs.ntfy.sh/)
- [ntfy GitHub](https://github.com/binwiederhier/ntfy)
