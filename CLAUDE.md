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

### Per-Connection RPC Data (`tcp_rpc_data`)
Stored in `connection_info.custom_data[256]`, accessed via `TCP_RPC_DATA(C)`. Field usage:
- `extra_int` — conn_tag (set in `mtproto_proxy_rpc_ready`)
- `extra_int2` — matched secret index + 1 (0 = unset; set during handshake)
- `extra_int3` — unused
- `extra_int4` — target DC number (set during obfuscated2 handshake)

### Cross-TU Globals Pattern
Globals are defined in `mtproto-proxy.c` and accessed via bare `extern` declarations in `net-tcp-rpc-ext-server.c` (not via a shared header). Examples: `direct_dc_connections_created`, `per_secret_connections[]`. Follow this pattern for new shared counters between these two files.

### Connection Type Switching (`c->type = &ct_foo`)
Any `conn_type_t` struct used via runtime pointer switch **must** have `check_conn_functions()` called on it first. This function fills in default `.reader`, `.writer`, `.read_write`, etc. — without it, those fields are NULL and the event loop will SIGSEGV. The function is auto-called only for listening connections and conn_target types; manually switched types (like `ct_direct_client`, `ct_direct_client_drs`, `ct_tcp_rpc_ext_server_drs`) need explicit calls. Use a `static int checked` guard to call once.

## Testing

### E2E Tests
- `tests/docker-compose.tls-test.yml` — full TLS E2E tests with nginx backend
- Telethon 1.42.0 does NOT support `ee` (fake-TLS) secrets — use [TelethonFakeTLS](https://pypi.org/project/TelethonFakeTLS/) extension
- TelethonFakeTLS has TWO bugs we monkey-patch in tests:
  1. `read_server_hello()` only reads the first encrypted record (patched in `test_tls_e2e.py`)
  2. `FakeTLSStreamWriter.write()` never sends CCS (`\x14\x03\x03\x00\x01\x01`) before the first data record — proxy rejects with "bad client dummy ChangeCipherSpec" (patched in `test_drs_e2e.py`)
- The `test_telethon_connects` test validates HMAC but can't complete auth_key exchange without real Telegram DC connectivity
- The `test-direct` CI job installs only `requests telethon` (not full `requirements.txt`) and runs natively on Ubuntu — new test dependencies must either be in stdlib or the test must degrade gracefully
- **Multi-secret test gotcha**: `test_wrong_secret_still_rejected` creates the "wrong" secret by flipping all bits of SECRET_1. If SECRET_2 is the bit-complement of SECRET_1, the test fails because the "wrong" secret matches SECRET_2. Use non-complementary secrets when running `docker-compose.multi-secret-test.yml` manually.

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
- **Data race (fixed):** client data can arrive before `tcp_direct_dc_connected` sends the obfuscated2 init. `tcp_direct_client_parse_execute` defers relay until `dc->crypto` is set; the connected callback resets `skip_bytes` and signals the client.
- **DC init must match client transport tag**: The obfuscated2 init sent to the DC must use the same transport tag (bytes 56-59) as the client used. The client's tag is stored in `D->extra_int3` and propagated through `direct_connect_to_dc` to `tcp_direct_dc_connected`. Hardcoding `0xeeeeeeee` broke all connections since clients always use `0xdddddddd`.
- **DC init must bypass crypto layer**: The 64-byte init is written to `c->out_p` (post-crypto buffer), NOT `c->out`. Writing to `c->out` would cause `crypto_encrypt_output` to double-encrypt the init, making it unreadable by the DC.
- **Connection lifecycle callbacks differ by mode**: Non-direct uses `mtproto_ext_rpc_ready`/`mtproto_ext_rpc_close` (in `mtproto-proxy.c`). Direct uses `direct_connect_to_dc`/`tcp_direct_close` (in `net-tcp-rpc-ext-server.c`). Note: `mtproto_proxy_rpc_ready`/`close` are declared but dead code — do not use them.

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

### Building RPM from Local Source
1. `cd ~/Projects/MTProxy && git archive --format=tar.gz --prefix=MTProxy-3.1.0/ HEAD > ~/Projects/mtproxy-rpm/v3.1.0.tar.gz`
2. Bump `Release:` in `mtproxy.spec` (builder skips if version already exists in repo)
3. `cd ~/Projects/mtproxy-rpm && docker run --rm --platform linux/amd64 -v "$(pwd):/sources" -v /tmp/rpmbuild-output:/output getpagespeed/rpmbuilder:el7`
4. RPM lands in `/tmp/rpmbuild-output/`

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
- **Adding new stats** requires updating **three** places in `mtproto-proxy.c`: the `worker_stats` struct, `update_local_stats_copy()`, and `add_stats()`. Missing any one silently drops the metric in multi-worker mode.
