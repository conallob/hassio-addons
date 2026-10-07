# Home Assistant Add-on: MyFitnessPal MCP

## Overview

This add-on runs [`myfitness-mcp`](https://github.com/delize/myfitness-mcp)
— a [Model Context Protocol](https://modelcontextprotocol.io/) server for
MyFitnessPal — using its native **streamable HTTP** transport, so Claude (as
a custom remote connector) or any other MCP client can read and write your
MyFitnessPal data:

| Area | Tools |
|------|-------|
| Food diary | `mfp_get_diary`, `mfp_add_food_to_diary`, `mfp_update_food_entry`, `mfp_delete_food_entry` |
| Foods | `mfp_search_food`, `mfp_get_food_details`, `mfp_get_recent_foods`, `mfp_get_frequent_foods`, `mfp_get_my_foods`, `mfp_create_food` |
| Body measurements | `mfp_get_measurements`, `mfp_set_measurement` |
| Exercise | `mfp_get_exercises` |
| Goals | `mfp_get_goals`, `mfp_set_goals` |
| Water | `mfp_get_water`, `mfp_set_water` |
| Reports | `mfp_get_report` |

See the [upstream README](https://github.com/delize/myfitness-mcp#tools) for
details of each tool.

**Endpoint**: `http://<home-assistant-host>:<port>/mcp`, where `<port>` is
whatever you map container port `8000` to in this add-on's **Network**
settings. The port is **not mapped by default** — set one before starting
the add-on, unless you only reach it through a reverse-proxy add-on (e.g.
Cloudflared, NGINX Proxy Manager) over Home Assistant's internal network.

There is no ingress panel: this add-on has no web UI of its own, and MCP
clients can't authenticate through Home Assistant's ingress proxy anyway.

---

## Step 1: Give the add-on your MyFitnessPal session cookies

MyFitnessPal's login page is captcha-protected, so this add-on **never asks
for your MyFitnessPal password**. Instead it reads session cookies from a
browser that is already logged in. Configure exactly one of the following
(if both a Firefox profile and a cookies file are set, the Firefox profile
wins and the cookies file is only a fallback).

Session cookies last roughly 30 days. When tools start failing with
authentication errors, log into MyFitnessPal again and refresh the cookies.

### Option A: `firefox_profile_dir` (recommended)

1. Log into [myfitnesspal.com](https://www.myfitnesspal.com) in Firefox.
2. Copy that Firefox profile's `cookies.sqlite` (and `cookies.sqlite-wal`
   if present) into a directory under `/share`, e.g. via the Samba add-on
   into `/share/myfitnesspal/firefox-profile/`. Find the profile directory
   from Firefox's `about:profiles` page. Copying the whole profile directory
   also works.
3. Set `firefox_profile_dir: /share/myfitnesspal/firefox-profile`.

The directory itself, or any directory one level below it, must contain a
`cookies.sqlite`. The file is re-read automatically whenever it changes, so
refreshing an expired session is just a matter of copying a new
`cookies.sqlite` over the old one — no add-on restart needed.

### Option B: `cookies_file`

Path to a JSON file holding the cookies, in either of these formats:

```json
{"cookies": {"cookie_name": "cookie_value", "...": "..."}}
```

```json
{"cookie_name": "cookie_value", "...": "..."}
```

Export every cookie for `myfitnesspal.com` from a logged-in browser (e.g.
the browser's developer tools, **Application/Storage → Cookies**), and save
the file either under `/share` (e.g. `/share/myfitnesspal/cookies.json`) or
in this add-on's own config folder, which appears inside the add-on as
`/config` (e.g. `cookies_file: /config/cookies.json`; on the host/Samba
share it's `addon_configs/<id>_myfitnesspal-mcp/cookies.json`). Like the
Firefox profile, the file is re-read automatically whenever it changes.

### Option C: `cookies_json`

The same JSON as Option B, pasted directly into this option instead of
saved to a file. Convenient, but refreshing expired cookies means editing
the add-on configuration (which restarts it). Can't be combined with
`cookies_file`.

---

## Step 2: Choose how MCP clients authenticate

### Option: `oauth_passcode` / `resource_url`

Set **both** to enable OAuth 2.1 (with dynamic client registration and
PKCE), which is what Claude's custom remote connectors require:

- `oauth_passcode`: a long random secret, e.g. the output of
  `python3 -c 'import secrets; print(secrets.token_urlsafe(32))'`.
- `resource_url`: the exact public URL clients use to reach this add-on,
  scheme and host only, no path — e.g. `https://mfp.example.com`.

Then, in Claude, add a custom connector with URL
`https://mfp.example.com/mcp`, leaving the OAuth client ID/secret blank.
Claude redirects you to the add-on's passcode page once; enter
`oauth_passcode` there.

Leave **both** empty to run **unauthenticated** — only do that if port 8000
is reachable from a trusted network alone. Setting just one of them is
treated as a misconfiguration and the add-on refuses to start.

The passcode proves "the caller knows the passcode", not identity — keep
network-level access control in front of any internet-facing deployment.

Issued OAuth tokens are held in memory only, so **restarting the add-on (or
Home Assistant) means re-entering the passcode** in each connected client.

### Option: `access_token_ttl`

Access token lifetime in seconds. When a token expires the client
re-authorizes, which may mean re-entering the passcode.

Default: `2592000` (30 days)

### Option: `allowed_hosts`

Comma-separated `Host` header values the server will accept, e.g.
`mfp.example.com,mfp.example.com:443` when behind a reverse proxy. Setting
this enables DNS-rebinding protection, and then **only** those hosts (plus
`localhost`) are accepted — so direct LAN access via
`http://<home-assistant-ip>:<port>` stops working unless you list that too.

Default: `""` (protection disabled; any `Host` is accepted)

---

## Exposing it to Claude

Claude's remote connectors need an HTTPS URL reachable from the internet.
The usual Home Assistant approaches work, for example:

- The **Cloudflared** add-on, with a public hostname pointing at this
  add-on's port 8000.
- The **NGINX Home Assistant SSL proxy** / **NGINX Proxy Manager** add-on,
  with a host forwarding to this add-on's port.

Whatever you use, set `resource_url` to the resulting public URL and
`allowed_hosts` to its host name.

---

## Known issues

- Not verified end to end on a live Supervisor install: the upstream server
  was smoke-tested on Python 3.11 (Debian bookworm's version, used by this
  add-on) with the same environment this add-on sets, but the container
  image itself has not been built and run under Supervisor yet.
- Session cookies expire (~30 days) and must be refreshed by hand, as
  described above.
- OAuth tokens don't survive an add-on restart (see above).
