# MTProxy — Project Guidelines

## Architecture Constraints

### TDLib Compatibility (Critical)
TDLib (used by ALL official Telegram clients — iOS, Android, Desktop) parses the fake-TLS ServerHello by reading **exactly one** `\x17\x03\x03` Application Data record after `\x14\x03\x03\x00\x01\x01` (CCS). It computes HMAC-SHA256 over only what it consumed (ServerHello + CCS + first record). Extra records are left in the input buffer and misinterpreted as MTProto data.

**Never emit multiple encrypted records in the ServerHello response.** Instead, combine all backend record sizes into a single record. See `TlsInit.cpp` in [tdlib/td](https://github.com/tdlib/td/blob/master/td/mtproto/TlsInit.cpp) lines 582-607.

### Fake-TLS HMAC Protocol
- Client: `HMAC(secret, zeroed_client_hello)` → writes result as client_random
- Server: `HMAC(secret, client_random || zeroed_response)` → writes result as server_random
- Both sides include the **full response** in the HMAC — but "full response" for TDLib means only up to the first encrypted record

### Docker NAT
The proxy **must** pass `--nat-info LOCAL_IP:EXTERNAL_IP` to work behind Docker NAT. Without it, the proxy announces its container-internal IP to Telegram DCs and connections silently fail. The upstream Telegram image auto-detects this; our Dockerfile does too via `icanhazip.com`.

## Testing

### E2E Tests
- `tests/docker-compose.tls-test.yml` — full TLS E2E tests with nginx backend
- Telethon 1.42.0 does NOT support `ee` (fake-TLS) secrets — use [TelethonFakeTLS](https://pypi.org/project/TelethonFakeTLS/) extension
- TelethonFakeTLS has a bug: `read_server_hello()` only reads the first record. We monkey-patch it in `test_tls_e2e.py`
- The `test_telethon_connects` test validates HMAC but can't complete auth_key exchange without real Telegram DC connectivity

### Fuzz Tests
- `fuzz/` directory — libFuzzer harnesses for TLS and HTTP parsers (requires Clang)
- `make fuzz CC=clang` builds; `make fuzz-run` runs all targets
- Pure parsing logic lives in `net/net-tls-parse.{c,h}` and `net/net-http-parse.{c,h}` — extracted specifically so fuzz harnesses can link without the full engine

### Building
Cannot build natively on macOS (needs Linux OpenSSL). Use `docker build --target builder` to verify compilation. The Docker image supports both `linux/amd64` and `linux/arm64` — on Apple Silicon Macs, `docker build` produces a native ARM64 binary.

### Direct-to-DC Mode
When `--direct` is passed (or `DIRECT_MODE=true` in Docker), the proxy connects straight to Telegram DCs instead of through ME relays. The code path branches in `net/net-tcp-rpc-ext-server.c` after the 64-byte obfuscated2 handshake: `direct_connect_to_dc()` opens a new obfuscated2 connection to the DC and sets up a bidirectional byte-level relay via `ct_direct_client`/`ct_direct_dc` connection types. No RPC proxy protocol is involved — raw MTProto bytes are piped through with double AES-CTR encryption (client↔proxy, proxy↔DC).

- DC addresses are hardcoded in `mtproto/mtproto-dc-table.c`
- Incompatible with `-P` (proxy tag) — ad tags require ME relays
- `proxy-multi.conf` and `proxy-secret` are not needed in direct mode

### Live Proxy Test
- `tests/test_live_proxy.py` — Telethon-based diagnostic for testing a running proxy instance (TCP, obfuscated2 handshake, multi-DC)
- Works with non-TLS proxies (`dd` prefix, `ConnectionTcpMTProxyRandomizedIntermediate`)
- Usage: `python3 tests/test_live_proxy.py --host HOST --port PORT --secret SECRET`

## RPM Packaging

RPM spec lives in a **separate repo**: `~/Projects/mtproxy-rpm` (Bitbucket: `danila_vershinin/mtproxy-rpm`).

### proxy-multi.conf Lifecycle (RPM)
1. **Build time**: `getProxyConfig` is fetched and baked in as `proxy-multi.conf-initial`
2. **Install**: RPM creates symlinks `proxy-multi.conf → proxy-multi.conf-initial`
3. **Post-install**: `%post` script downloads fresh config, replaces symlink with real file
4. **Runtime**: `/etc/cron.daily/mtproxy` refreshes the config daily and reloads the service

**Gotcha**: If the `%post` download fails (network issue during install), the proxy runs with the build-time config which may have stale ME relay addresses. Telegram rotates relay IPs/ports frequently — a config even hours old can have unreachable addresses.

### Production Instance
- Host: `mtproxy.getpagespeed.com` (SSH: `centos@m1.sgweddingfavors.com`, then sudo)
- Port: 8444, stats: 8888
- Mode: ME relay (obfuscated2 + proxy tag), no fake-TLS
- Config: `/etc/mtproxy/mtproxy.params`, `/etc/mtproxy/secret`
- Data: `/usr/share/mtproxy/proxy-{secret,multi.conf}`
- Service: `systemctl {status,restart,reload} mtproxy`

## Common Pitfalls
- **Do not use `--no-verify` or force-push to master** without explicit approval
- The `proxy-secret` (aes-pwd) file is baked into the Docker image at build time — not fetched at runtime
- `proxy-multi.conf` is refreshed every 6 hours via cron inside the container (not in direct mode)
- **RPM upgrades reset `proxy-multi.conf`** to a symlink to the build-time snapshot — the `%post` script must download a fresh copy
