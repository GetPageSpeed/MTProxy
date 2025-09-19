# Changelog

All notable changes to this project will be documented in this file.

## 2025-09-19

- Added IPv6 usage documentation to `README.md`:
  - How to enable IPv6 with `-6` and use `-H <port>`
  - Client guidance (prefer hostname with AAAA record; IPv6 literal notes)
  - Quick checks and troubleshooting (sysctl, firewall, V6ONLY)
  - Systemd IPv6 example
  - Docker IPv6 considerations

- Code fixes and improvements:
  - `jobs/jobs.c`: safer signal handler logging using `snprintf` and bounded write
  - `common/proc-stat.c`: correct parsing of `/proc/<pid>/stat` by reading `comm` as `(%[^)])`
  - `net/net-events.c`: correct IPv4 prefix-length print and IPv6 netmask bit scan
  - `net/net-http-server.c`/`net-http-server.h`: fix HTTP date formatting to exact RFC 7231 form, use `HTTP_DATE_LEN` and `snprintf`

- Build and tooling:
  - `Makefile`: improve host arch detection and optional 32/64-bit flags; add Docker-based test targets; tidy linker flags
  - `Dockerfile`: consistent multi-stage alias casing (`AS builder`)
  - `.gitignore`: add IDE files (`.idea/`)


