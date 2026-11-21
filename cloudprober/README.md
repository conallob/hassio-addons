# Home Assistant Add-on: Cloudprober

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

[Cloudprober](https://cloudprober.org) runs synthetic probes (HTTP, ping, DNS,
TCP, external scripts and more) against your services and exports the results
as Prometheus metrics.

## About

This add-on runs the official static Cloudprober binary. The main pipeline is
set in the add-on configuration, and an additional config file stored under
`/homeassistant` (your Home Assistant config directory) can be included, so
probe definitions can be managed in git alongside the rest of your HA config.

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg

[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
