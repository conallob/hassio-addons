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

**Endpoint**: `http://<home-assistant-host>:8642/mcp` (streamable HTTP).
The ingress panel proxies the same endpoint through the HA sidebar.

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

---

## Ports

| Port | Purpose |
|------|---------|
| 8642 | Streamable-HTTP MCP endpoint (ingress; also usable directly, e.g. from another device's MCP client) |

## Persistent Storage

Sync client state (the local encrypted database cache and sync cursor) is
kept at `/data/omnifocus-sync-mcp/client.json` inside the add-on's own
persistent `/data`, so it survives add-on restarts and updates without
needing any `/config` or `/share` mapping.

## Build Note

`rosskukulinski/omnifocus-sync-mcp` has no Dockerfile and no tagged releases
at the time this add-on was written, so the image builds by cloning the
source at the git ref in `build.yaml`'s `OMNIFOCUS_SYNC_MCP_REF` build
argument (`main` by default) and compiling it with `npm run build`. Pin that
argument to a specific commit SHA once you've verified a build against your
account, so rebuilds stay reproducible instead of silently picking up
upstream changes.

## Known Issues

This add-on has not been build- or run-verified against a live Supervisor
install (no Docker daemon was available when authoring it), and the
`supergateway` bridge's exact HTTP/ingress behavior (in particular whether it
binds to all interfaces, and how it handles the ingress path prefix) has not
been confirmed against a running container. If the ingress panel 404s or the
connection is refused, try connecting an MCP client directly to
`http://<home-assistant-host>:8642/mcp` first to isolate whether the issue
is ingress-proxy-specific.

## OmniFocus / omnifocus-sync-mcp Documentation

- [omnifocus-sync-mcp on GitHub](https://github.com/rosskukulinski/omnifocus-sync-mcp)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [supergateway](https://github.com/supercorp-ai/supergateway)
