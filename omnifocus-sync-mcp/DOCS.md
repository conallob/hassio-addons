# Home Assistant Add-on: OmniFocus Sync MCP

## Overview

This add-on runs [`omnifocus-sync-mcp`](https://github.com/rosskukulinski/omnifocus-sync-mcp)
— a headless [Model Context Protocol](https://modelcontextprotocol.io/) server
that reads and writes your OmniFocus tasks directly via Omni Sync Server
(WebDAV + client-side end-to-end decryption). No Mac, no OmniFocus app, and
no local automation running on a Mac are required — only your Omni Sync
Server (OmniFocus > Sync) account credentials.

Upstream only implements the MCP **stdio** transport (for tools like Claude
Desktop that spawn a local process). This add-on wraps it with
[`supergateway`](https://github.com/supercorp-ai/supergateway) to expose it
as **streamable HTTP** instead, so any MCP client on your network — or a tool
running through the Home Assistant ingress panel — can reach it over HTTP.
Since `supergateway` itself has no concept of authenticating incoming
requests, a small reverse proxy (`auth-proxy`, its own add-on service) sits
in front of it and enforces `auth_mode` before forwarding anything through —
see that option below.

**Endpoint**: `http://<home-assistant-host>:8642/mcp` (streamable HTTP).
The ingress panel proxies the same endpoint through the HA sidebar. Either
way, requests must satisfy `auth_mode` (see below) or they're rejected with
`401 Unauthorized` before ever reaching `supergateway` or OmniFocus.

---

## Options

### Option: `sync_username` / `sync_password`

**Required.** The same account name and password you use for
`OmniFocus > Sync` in the OmniFocus app itself.

### Option: `encryption_passphrase`

Omni Sync Server databases are end-to-end encrypted. OmniFocus derives the
encryption passphrase from your sync password by default — leave this blank
unless you explicitly set a *separate* encryption passphrase in OmniFocus's
sync settings.

Default: `""` (falls back to `sync_password`)

### Option: `sync_url`

Override the Omni Sync Server endpoint. Only needed for a self-hosted WebDAV
server instead of Omni Group's own sync service.

Default: `""` (upstream default: `https://sync.omnigroup.com`)

### Option: `database`

The database filename on the sync server, if you use something other than
the default.

Default: `""` (upstream default: `OmniFocus.ofocus`)

### Option: `client_name`

The client identifier this add-on registers with Omni Sync Server, visible
in OmniFocus's "Manage synced clients" list.

Default: `""` (add-on sets `omnifocus-sync-mcp@home-assistant`)

### Option: `read_only`

When enabled, refuses all writes (task creation, edits, completion,
deletion) — the MCP server can only read and list tasks.

Default: `false`

### Option: `auth_mode`

How the `:8642` endpoint authenticates incoming requests, before they ever
reach `supergateway` or your OmniFocus data. One of:

| Value | Behavior |
|-------|----------|
| `bearer` **(default)** | Requests must carry `Authorization: Bearer <bearer_token>`, checked with a constant-time comparison against the configured `bearer_token`. |
| `oauth2_introspection` | Requests must carry `Authorization: Bearer <token>`; that token is validated by calling your OAuth 2.0 authorization server's [RFC 7662](https://www.rfc-editor.org/rfc/rfc7662) token introspection endpoint (`oauth2_introspection_url`) and requiring `"active": true` in the response. |
| `none` | No auth — anyone who can reach `:8642` can read/write your OmniFocus tasks. Only use this if you're already restricting network access to this port yourself (e.g. a firewalled LAN, or a VPN-only exposure), since ingress itself does not add its own authentication layer for this kind of non-interactive API endpoint. |

Since this add-on has no browsable UI, the ingress panel entry exists mainly
so the add-on has a presence in the HA sidebar for status/logs — actual usage
is an MCP client (Claude Desktop, a script, etc.) connecting directly to
`:8642/mcp` with credentials, and `auth_mode` applies identically whether the
request arrives via ingress or directly.

Default: `bearer`

### Option: `bearer_token`

The shared secret required when `auth_mode` is `bearer`. Generate a long
random value yourself (e.g. `openssl rand -hex 32`) and configure the same
value in your MCP client as an `Authorization: Bearer <token>` header.

Default: `""` (**required** when `auth_mode` is `bearer`; the add-on refuses
to start without it)

### Option: `oauth2_introspection_url`

Your OAuth 2.0 authorization server's token introspection endpoint (RFC
7662), used only when `auth_mode` is `oauth2_introspection`. The auth proxy
POSTs `token=<the client's bearer token>&token_type_hint=access_token` to
this URL and requires a JSON response containing `"active": true`.

Default: `""` (**required** when `auth_mode` is `oauth2_introspection`)

### Option: `oauth2_introspection_auth_header`

Many authorization servers require the introspection *call itself* to be
authenticated (as the OAuth client, not the end user) — e.g.
`client_id`/`client_secret` sent as HTTP Basic auth. If your server needs
this, set the full `Authorization` header value here (for example
`Basic base64(client_id:client_secret)` or `Bearer <a static service token>`)
and the auth proxy sends it on every introspection request. Leave blank if
your introspection endpoint doesn't require its own auth.

Default: `""`

### Option: `listen_address`

The address the `:8642` endpoint (the auth proxy — see Options above)
binds to inside the add-on's container. Use this if you want to run your
own reverse proxy or ingress in front of this add-on instead of relying on
Home Assistant's ingress panel, or if your Supervisor host is multi-homed
(multiple network interfaces/IPs) and you want to restrict which one this
add-on is reachable on.

**Leave this at the default (`0.0.0.0`, all interfaces) unless you have a
specific reason to change it.** Two things to know before changing it:

- Setting it to `127.0.0.1` makes the endpoint reachable only from
  *inside this add-on's own container* — not from the Supervisor host, not
  from another add-on, and **not from the Home Assistant ingress panel**,
  which connects to the container over its internal Docker network address,
  never `127.0.0.1`. Only set this if nothing outside the container needs to
  reach it, which is unusual for an add-on.
- Restricting to one specific LAN IP only has an effect if the container
  itself is bound to multiple addresses (e.g. host networking or a macvlan
  setup) — under standard Docker bridge networking (the default for HA
  add-ons), the container has a single internal IP, and `listen_address`
  narrowing beyond `0.0.0.0` there doesn't add meaningful restriction; use
  your network's own firewall/VLAN controls for that instead.

This is a **host/IP only** — do not append a port (`192.168.1.3:48642`).
The internal container port is fixed at `8642` by `config.yaml` (both the
ingress panel and the host port mapping target that exact port), so it
can't be changed here; a `host:port` or `[ipv6]:port` value is accepted for
convenience, but the port part is only logged as a warning and then
discarded, not applied. To expose this add-on on a different *external*
port, use this add-on's own **Network** settings in Home Assistant (which
remap the host-side port to the container's fixed `8642` — no add-on
configuration needed for that).

Default: `0.0.0.0`

---

## Ports

| Port | Purpose |
|------|---------|
| 8642 | Auth-proxied streamable-HTTP MCP endpoint (ingress; also usable directly, e.g. from another device's MCP client). Requests must satisfy `auth_mode` — see Options above. `supergateway` itself only listens on `127.0.0.1:8643`, inside the container, and is never reachable directly. |

## Persistent Storage

Sync client state (the local encrypted database cache and sync cursor) is
kept at `/data/omnifocus-sync-mcp/client.json` inside the add-on's own
persistent `/data`, so it survives add-on restarts and updates without
needing any `/config` or `/share` mapping.

## Build Note

`rosskukulinski/omnifocus-sync-mcp` has no Dockerfile and no tagged releases
(its own `package.json` is still `0.1.0`), so the image builds by cloning
the source at the git ref pinned in `build.yaml`'s `OMNIFOCUS_SYNC_MCP_REF`
build argument (a commit SHA, not "main" — see that file for how to update
it) and compiling it with `npm run build`.

**This add-on's own `version` in `config.yaml` is independent of upstream's
version** — bump it whenever this add-on's own files change (including a
new `OMNIFOCUS_SYNC_MCP_REF` pin), even if upstream's version number hasn't
moved. Supervisor keys its locally-built image cache off this add-on's
`version`; if you edit the add-on and rebuild without bumping it, Supervisor
can silently reuse the old cached image instead of actually rebuilding.

## Known Issues

This add-on has not been build- or run-verified against a live Supervisor
install (no Docker daemon was available when authoring it), and the auth
proxy's exact behavior through the ingress path prefix has not been
confirmed against a running container. If the ingress panel 404s or the
connection is refused, try connecting an MCP client directly to
`http://<home-assistant-host>:8642/mcp` (with the configured `auth_mode`
credentials) first to isolate whether the issue is ingress-proxy-specific.

## OmniFocus / omnifocus-sync-mcp Documentation

- [omnifocus-sync-mcp on GitHub](https://github.com/rosskukulinski/omnifocus-sync-mcp)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [supergateway](https://github.com/supercorp-ai/supergateway)
- [RFC 7662 — OAuth 2.0 Token Introspection](https://www.rfc-editor.org/rfc/rfc7662)
