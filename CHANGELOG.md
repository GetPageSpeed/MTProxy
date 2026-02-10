# Changelog

All notable changes to this project will be documented in this file.

## [3.0.9] - 2026-02-10

### Added
- `EE_DOMAIN` environment variable for Docker to enable EE mode (Fake-TLS) ([#30](https://github.com/GetPageSpeed/MTProxy/pull/30))

## [3.0.8] - 2025-12-07

### Fixed
- Docker startup failure when `SECRET` not provided ([#21](https://github.com/GetPageSpeed/MTProxy/issues/21)):
  - Added `vim-common` package to provide `xxd` for automatic secret generation
  - Secret is now auto-generated if not provided via environment variable
- Container "cannot raise open file limit" error:
  - Added `-c` flag with `MAX_CONNECTIONS` env var (default: 60000)
  - Added `ulimits` configuration to docker-compose files

### Added
- CI testing workflow with GitHub Actions
- Simplified test suite (HTTP stats + MTProto port connectivity)
- `TESTING.md` documentation
- Docker Quick Start section in README - run with zero configuration
- `EXTERNAL_IP` environment variable for NAT support in Docker
- Explicit `--platform linux/amd64` in Dockerfile for Apple Silicon compatibility

### Changed
- Simplified test suite - removed Telethon dependency for faster, more reliable CI
- Updated Docker documentation with clearer examples

## 2025-11-28

- Fixed high CPU usage (Issue #100):
  - Optimized `epoll_wait` timeout in `net/net-events.c` to be dynamic based on pending timers.
  - Corrected `epoll_timeout` handling in `engine/engine.c` and `mtproto/mtproto-proxy.c`.
- Fixed Docker startup issue (Issue #21):
  - Added `vim-common` to `Dockerfile` to provide `xxd` for secret generation.
- Added comprehensive test suite:
  - Added `tests/` directory with Python-based tests using `telethon`.
  - Added `make test` target for running tests in Docker.
  - Added `TESTING.md` documentation.
  - Added GitHub Actions workflow for automated testing.
- Build fixes:
  - Added missing headers (`<x86intrin.h>`) in `engine/engine-rpc.h`.
  - Suppressed array-bounds warnings for specific files.

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


