# Changelog

All notable changes to this project will be documented in this file.

## [3.0.22] - 2026-03-25

### Added
- Fuzz testing for protocol parsers — libFuzzer harnesses with ASan + UBSan for TLS ClientHello/ServerHello and HTTP request parsing. Extracted pure parsing logic into standalone modules (`net/net-tls-parse.{c,h}`, `net/net-http-parse.{c,h}`) so harnesses link without the full engine. CI runs each target for 60 seconds on every push/PR ([#51](https://github.com/GetPageSpeed/MTProxy/issues/51))
- E2E tests for anti-detection fallback scenarios: unknown SNI forwarding, duplicate `client_random` replay rejection, and standard browser TLS passthrough ([#45](https://github.com/GetPageSpeed/MTProxy/issues/45))
- Documented anti-detection properties of TCP Splitting mode — all validation failures are transparently forwarded to the backend

## [3.0.21] - 2026-03-25

### Added
- Direct-to-DC mode (`--direct` / `DIRECT_MODE=true`) — bypass Telegram middle-end relay servers and connect straight to data centers. Eliminates one network hop, removes dependency on `proxy-multi.conf` / `proxy-secret`, and simplifies deployment. Incompatible with `-P` (proxy tag) ([#53](https://github.com/GetPageSpeed/MTProxy/issues/53))

### Fixed
- Stats port (`-p`) now binds to `0.0.0.0` instead of `127.0.0.1` — Docker port mapping (`-p 8888:8888`) works for accessing stats from the host ([#35](https://github.com/GetPageSpeed/MTProxy/issues/35))
- Prometheus `/metrics` endpoint no longer prepends non-Prometheus engine stats

## [3.0.20] - 2026-03-24

### Added
- IP blocklist/allowlist support (`--ip-blocklist`, `--ip-allowlist`) — CIDR-based access control for client connections. Files support IPv4/IPv6 notation with comments, reloaded on `SIGHUP`. Prometheus metric `mtproxy_ip_acl_rejected_total` tracks rejections. Docker support via `IP_BLOCKLIST`/`IP_ALLOWLIST` environment variables ([#46](https://github.com/GetPageSpeed/MTProxy/issues/46))
- CI: static analysis with cppcheck and CodeQL. Fixed undefined behavior (signed left-shifts), potential memory leak in `parse_option_internal()`, guarded memcpy with NULL checks ([#52](https://github.com/GetPageSpeed/MTProxy/issues/52))

## [3.0.19] - 2026-03-24

### Fixed
- Reduce idle CPU usage from 1-2% to 0% — the precise cron job (1ms interval) now stops when no clients are connected and resumes instantly on first accept. In multi-worker mode, the master process is unaffected (always monitors children) ([#34](https://github.com/GetPageSpeed/MTProxy/issues/34))
- E2E tests: provide a default test secret so all TLS handshake tests pass without requiring `MTPROXY_SECRET` env var

## [3.0.18] - 2026-03-24

### Added
- ARM64 (aarch64) support — Docker images now build for both `linux/amd64` and `linux/arm64`, enabling native deployment on Raspberry Pi, Oracle Cloud ARM, Apple Silicon, and other ARM64 platforms ([#48](https://github.com/GetPageSpeed/MTProxy/issues/48))
- CI: ARM64 test job on native GitHub ARM runner
- Makefile: `docker-image-arm64` and `docker-run-help-arm64` targets

### Changed
- CRC32/CRC32C uses table-based software fallback on ARM64 (functionally correct; hardware-accelerated ARMv8 CRC can be added later)
- Dockerfile no longer hardcodes `--platform=linux/amd64`

## [3.0.17] - 2026-03-24

### Added
- Prometheus-compatible `/metrics` endpoint on the stats port — returns counters and gauges in exposition format for scraping ([#47](https://github.com/GetPageSpeed/MTProxy/issues/47))
- Docker: support multiple secrets via comma-separated `SECRET` or numbered `SECRET_1`..`SECRET_16` environment variables ([#54](https://github.com/GetPageSpeed/MTProxy/issues/54))
- Docker: print ready-to-share `https://t.me/proxy` connection links at startup ([#55](https://github.com/GetPageSpeed/MTProxy/issues/55))
- Docker: switch to Alpine Linux — image size reduced from ~150MB to ~8MB ([#49](https://github.com/GetPageSpeed/MTProxy/issues/49))

### Security
- Use constant-time comparison (`CRYPTO_memcmp`) for HMAC validation, preventing timing side-channel attacks
- Tighten timestamp replay window from 10 minutes to 2 minutes (matching telemt)

## [3.0.16] - 2026-03-24

### Fixed
- **Critical**: v3.0.15 broke fake-TLS for backends that send multiple encrypted records — TDLib (all official Telegram clients) only reads the first record and the HMAC mismatch caused connection failures. Now emits a single record whose size equals the **total** of all backend records, giving a realistic encrypted payload size without breaking any client ([#42](https://github.com/GetPageSpeed/MTProxy/issues/42))
- Auto-detect external IP for Docker NAT — proxy now discovers its public IP automatically, fixing silent connection failures when `EXTERNAL_IP` was not set
- Added `--allow-skip-dh` flag (upstream default) for faster DC handshakes
- E2E tests now use TelethonFakeTLS for real fake-TLS handshake verification

## [3.0.15] - 2026-03-24 [YANKED]

### Fixed
- ~~Fake-TLS emulation now replays all encrypted Application Data records from the backend~~ — **BROKEN**: emitting multiple records is incompatible with TDLib's single-record ServerHello parser. Use v3.0.16 instead

## [3.0.14] - 2026-03-23

### Added
- Automatic daily refresh of `proxy-multi.conf` via cron — prevents proxy from becoming unavailable when Telegram rotates DC server addresses ([#41](https://github.com/GetPageSpeed/MTProxy/issues/41))
- `HEALTHCHECK` instruction in Dockerfile — health monitoring now works with plain `docker run`, not just Docker Compose

## [3.0.13] - 2026-03-21

### Added
- `-D host:port` support for custom TLS backend — proxy MTProto traffic to your own web server instead of a remote domain
- Custom TLS backend setup guide in README
- `--aes-pwd` flag documentation in README ([#38](https://github.com/GetPageSpeed/MTProxy/pull/38), fixes [#36](https://github.com/GetPageSpeed/MTProxy/issues/36))

### Fixed
- `proxy-secret` baked into Docker image at build time — eliminates runtime download failures and speeds up container startup
- Download resilience for `proxy-multi.conf` with better retry logic and cached fallback

## [3.0.12] - 2026-03-17

### Fixed
- `VERSION_STR` was hardcoded as `mtproxy-3.0.5` regardless of actual release — now injected from git tags at build time ([#37](https://github.com/GetPageSpeed/MTProxy/issues/37))

## [3.0.11] - 2026-03-17

### Fixed
- Stats endpoint (`--http-stats`) now accessible from all RFC 1918 private networks, not just loopback ([#35](https://github.com/GetPageSpeed/MTProxy/issues/35)). Fixes stats being unreachable from Docker host via bridge network.

## [3.0.10] - 2026-02-16

### Fixed
- LOCAL_IP detection in Docker for RouterOS containers where `/etc/hosts` contains empty lines ([#31](https://github.com/GetPageSpeed/MTProxy/pull/31))

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


