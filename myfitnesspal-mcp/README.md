# Home Assistant Add-on: MyFitnessPal MCP

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

A [Model Context Protocol](https://modelcontextprotocol.io/) server for
MyFitnessPal, reachable over streamable HTTP from Claude (as a remote
connector) or any other MCP client.

## About

This add-on packages [`delize/myfitness-mcp`](https://github.com/delize/myfitness-mcp),
which exposes your MyFitnessPal food diary, food search, custom foods,
exercises, body measurements, nutrition goals, water intake and nutrition
reports as MCP tools — both reads and writes. It authenticates to
MyFitnessPal with browser session cookies (MyFitnessPal's login is
captcha-protected), and to MCP clients with an optional OAuth 2.1 passcode
flow.

See [DOCS.md](DOCS.md) for setup, configuration options, and known issues.

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg

[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
