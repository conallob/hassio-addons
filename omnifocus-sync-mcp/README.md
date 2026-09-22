# Home Assistant Add-on: OmniFocus Sync MCP

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

An HTTP [Model Context Protocol](https://modelcontextprotocol.io/) interface
to your OmniFocus task list, synced via Omni Sync Server — no Mac or
OmniFocus app required.

## About

This add-on packages [`omnifocus-sync-mcp`](https://github.com/rosskukulinski/omnifocus-sync-mcp),
a headless MCP server that talks to Omni Sync Server directly over WebDAV
with client-side end-to-end decryption, and fronts it with
[`supergateway`](https://github.com/supercorp-ai/supergateway) so it's
reachable over streamable HTTP instead of only stdio — usable from the Home
Assistant ingress panel or any MCP client on your network.

See [DOCS.md](DOCS.md) for configuration options, the HTTP endpoint, and
known issues.

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg

[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
