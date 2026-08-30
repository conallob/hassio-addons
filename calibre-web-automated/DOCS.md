# Home Assistant Add-on: Calibre-Web Automated

## Overview

Calibre-Web Automated (CWA) manages a Calibre library through a web UI and
automates the boring parts: drop a book into a watched ingest folder and it
gets converted, added to the library, checked for a cover, and (optionally)
converted to Kepub for Kobo sync — no manual `calibredb` or Calibre-Web admin
steps required.

The add-on's version tracks the upstream [Calibre-Web Automated release](https://github.com/crocodilestick/Calibre-Web-Automated/releases)
it bundles one-to-one — check `config.yaml`'s `version` (or `build.yaml`'s
`CWA_VERSION` for the exact git tag fetched at build time) to see which CWA
release is currently packaged.

This add-on runs the upstream CWA application, the real Calibre binaries and
kepubify unmodified; only the surrounding container (base image, init
scripts, volume layout) is adapted for Home Assistant's Supervisor and
s6-overlay conventions.

On first start, CWA creates its own SQLite databases (`app.db`, `cwa.db`) and
prompts you to create an admin account the first time you open the web UI —
there's no add-on option for that.

---

## Options

### Option: `library_dir`

Path, relative to `/share`, where the Calibre library lives. Created
automatically if it doesn't exist. Point this at an existing library to
import it as-is.

Default: `calibre-web-automated/library`

### Option: `ingest_dir`

Path, relative to `/share`, that CWA watches for new ebooks to
automatically import. Drop a supported file (EPUB, MOBI, AZW3, PDF, CBZ/CBR,
and others) in here via Samba/the File editor add-on and CWA picks it up
within seconds.

Default: `calibre-web-automated/ingest`

### Option: `network_share_mode`

Set this to `true` if `/share` is itself a network mount (NFS/SMB) on your
Home Assistant host. `inotify`-based file watching is unreliable over
network filesystems, so this switches the ingest watcher and metadata change
detector to a polling fallback instead, and skips `chown`-ing files it
doesn't need to touch on the mount.

Default: `false`

---

## Volumes

CWA's own app state (`app.db`, `cwa.db`, conversion temp files, etc.) lives
under the add-on's private, persistent `/data` volume — not under `/share`
or Home Assistant's own `/config` — since it's internal application state,
not something to browse or edit directly. The library and ingest folders
above are the two paths you're expected to interact with, both under
`/share` so they're reachable from other add-ons (e.g. Samba) too.

| Container path | Backed by |
|---|---|
| `/config` (CWA's own, not HA's) | `/data/config` |
| `/calibre-library` | `/share/<library_dir>` |
| `/cwa-book-ingest` | `/share/<ingest_dir>` |

## Ports

| Port | Purpose |
|------|---------|
| 8083 | Calibre-Web Automated web UI (also mappable directly) |
| 8084 | Ingress-only reverse proxy in front of 8083 (internal; not mapped) |

## Known limitations

- **RAR/CBR extraction**: full RAR5 support requires the proprietary `unrar`
  binary, which isn't packaged for Debian. The build falls back to
  `unrar-free` (RAR3-era support only) when available; older or RAR5-format
  `.cbr`/`.rar` files may fail to extract.
- **Kernel/Qt6 compatibility**: CWA's own `cwa-init` service checks the host
  kernel version and strips Qt6 ABI tags on very old kernels (pre-6.0) to
  keep PDF/WebEngine features working; this is unchanged from upstream.
- This add-on has not yet been build- or run-tested against a live
  Supervisor install — see the README for details.

## Upstream documentation

- [Calibre-Web Automated wiki](https://github.com/crocodilestick/Calibre-Web-Automated/wiki)
- [Calibre-Web Automated README](https://github.com/crocodilestick/Calibre-Web-Automated#readme)
