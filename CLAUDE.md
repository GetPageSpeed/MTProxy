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

### Building
Cannot build natively on macOS (needs Linux OpenSSL). Use `docker build --target builder` to verify compilation. The Docker image supports both `linux/amd64` and `linux/arm64` — on Apple Silicon Macs, `docker build` produces a native ARM64 binary.

## Common Pitfalls
- **Do not use `--no-verify` or force-push to master** without explicit approval
- The `proxy-secret` (aes-pwd) file is baked into the Docker image at build time — not fetched at runtime
- `proxy-multi.conf` is refreshed every 6 hours via cron inside the container
