# Architecture Comparison: MTProxy Implementations

This document compares the architecture, performance, and safety of the main
MTProxy implementations and recommends a winning design direction.

## Projects Compared

| Project | Language | Maintainer | Status |
|---------|----------|-----------|--------|
| [TelegramMessenger/MTProxy](https://github.com/TelegramMessenger/MTProxy) | C | Telegram | Abandoned |
| **[GetPageSpeed/MTProxy](https://github.com/GetPageSpeed/MTProxy)** (this fork) | C | @dvershinin | **Active** |
| [9seconds/mtg](https://github.com/9seconds/mtg) | Go | 9seconds | Active |
| [telemt/telemt](https://github.com/telemt/telemt) | Rust | telemt | Active |

---

## 1. Architecture Overview

### This Fork (GetPageSpeed/MTProxy) — C

**Networking model:** Single-threaded, event-driven `epoll` loop with optional
multi-process workers (`-M`). Each worker is a `fork()`-ed child sharing stats
via `mmap`.

**Key components:**

| Layer | Files | Role |
|-------|-------|------|
| Event loop | `engine/engine.c` | `epoll_wait` dispatch, timers, signals |
| Connections | `net/net-connections.c` | Pool of 64K slots, state machine (connecting → working → close) |
| TCP I/O | `net/net-tcp-connections.c` | `readv`/`writev` scatter-gather, `TCP_NODELAY` |
| Crypto | `net/net-crypto-aes.c`, `crypto/aesni256.c` | AES-256-IGE via OpenSSL EVP, DH-2048 key exchange |
| Protocol | `mtproto/mtproto-proxy.c` | Packet forwarding, secret management, HTTP stats |
| DPI evasion | `net/net-tcp-drs.c` | Dynamic Record Sizing + Weibull inter-record delays |
| Buffers | `net/net-msg.c` | Zero-copy linked-list `raw_message` with refcounting |
| Jobs | `jobs/jobs.c` | Lock-free multi-producer queue for inter-thread work |

**Strengths:**
- Lowest per-connection overhead (static pools, no GC, no runtime).
- Battle-tested codebase from the official Telegram repository.
- `epoll` + non-blocking sockets is the most efficient Linux I/O model.
- Zero-copy buffer design minimises memory copies in the hot path.
- Comprehensive CI: libFuzzer, ASan, CodeQL, cppcheck, Telethon E2E.

**Weaknesses:**
- Manual memory management — historical bugs (heap overflow in `CONN_INFO`,
  use-after-free in `free_msg_buffers_chunk_internal`) required careful auditing.
- Single-threaded per worker — cannot utilise multiple cores within one process
  without forking.
- No built-in SOCKS5 upstream chaining.

### mtg — Go

**Networking model:** Goroutine-per-connection. Each accepted client spawns a
goroutine pair (reader + writer) that proxy bytes between the client and a
Telegram DC connection. The Go runtime multiplexes goroutines onto OS threads
via its M:N scheduler.

**Key design choices:**
- "Highly opinionated" — single secret only, no ad tag, no management UI.
- Stateless by design; configuration is a single CLI invocation.
- Domain-fronting anti-censorship via SNI and custom TLS dialer.
- `mtglib` exported as a Go library for embedding.
- v2 is a complete rewrite from v1 with improved reliability.

**Strengths:**
- Memory safety from garbage collection (no buffer overflows, no use-after-free).
- Goroutines handle 10–20K concurrent connections with low boilerplate.
- Simple deployment: single static binary, minimal configuration.
- SOCKS5 upstream proxy support for multi-hop censorship evasion.

**Weaknesses:**
- GC pauses under heavy allocation (goroutine stacks, TLS buffers).
- Higher baseline memory — Go runtime + GC metadata ≈ 10–20 MB idle.
- No multi-secret support; intentionally refuses to scale to large public proxies.
- No ad tag — prevents channel promotion use case.
- Docker image ~3.5 MB but runtime RSS is significantly higher than C.

### telemt — Rust + Tokio

**Networking model:** Async tasks on the Tokio multi-threaded runtime. Each
connection is a lightweight `Future` polled by the Tokio work-stealing
scheduler. Reader/writer halves are split (`tokio::io::split`) for concurrent
bidirectional proxying.

**Key design choices:**
- Full feature parity with the original: ad tag, multiple secrets, TLS fronting.
- Middle-End connection pool with adaptive refill and trio-state tracking.
- REST management API for live configuration changes.
- Per-user unique IP limits (anti-abuse).
- Atomic config reloading without downtime.

**Strengths:**
- Memory safety without GC — Rust's ownership model eliminates data races
  and use-after-free at compile time.
- Tokio's work-stealing scheduler efficiently utilises all cores.
- Lowest theoretical overhead: no GC, no runtime beyond Tokio's threadpool.
- Full feature set (ad tag, multi-secret, SOCKS5, management API).

**Weaknesses:**
- Tokio's task scheduling adds overhead vs. raw `epoll` (vtable dispatch,
  waker allocation, `Arc` reference counting).
- Harder to audit — Rust's async desugaring produces complex state machines.
- Smaller community; fewer production deployments than the C codebase.
- No fuzz testing in CI; partial anti-replay protection.

---

## 2. Language Comparison

| Criterion | C | Go | Rust |
|-----------|---|-----|------|
| **Runtime overhead** | None — syscalls only | GC + goroutine scheduler (~10 MB baseline) | Tokio threadpool (~2 MB baseline) |
| **Memory safety** | Manual (bugs happen) | GC-safe (no buffer overflows) | Compile-time safe (ownership + borrow checker) |
| **Concurrency model** | `fork()` workers + `epoll` | Goroutines (M:N green threads) | `async`/`await` tasks (work-stealing) |
| **Max throughput** | Highest (zero abstraction) | High (but GC pauses at scale) | Very high (near-C, no GC) |
| **Tail latency** | Predictable (no GC) | GC pauses (p99 spikes) | Predictable (no GC) |
| **Ease of contribution** | Moderate (undefined behaviour risks) | Easy (safe by default, simple syntax) | Moderate (steep learning curve, but safe) |
| **Binary size** | ~2 MB static | ~8 MB | ~5 MB |
| **Cross-compilation** | Requires toolchain per arch | Built-in (`GOOS`/`GOARCH`) | `cargo` + target triples |
| **Ecosystem** | POSIX + OpenSSL | Rich standard library | Tokio, `rustls`, `ring` |

**Verdict:** For a network proxy where predictable latency and minimal overhead
matter most, **C and Rust** are the strongest choices. Go is excellent for
rapid development but its GC introduces unpredictable tail latency at scale.
Rust offers C-level performance with compile-time safety guarantees, making it
the theoretically optimal choice for new development. However, the existing C
codebase has significant production mileage that Rust alternatives have not yet
matched.

---

## 3. Performance Comparison

### Throughput

| Implementation | I/O Model | Per-connection overhead | Theoretical max |
|---------------|-----------|----------------------|----------------|
| **This fork (C)** | `epoll` + `readv`/`writev` | ~80 bytes (connection slot) + AES context | Limited by kernel TCP stack |
| mtg (Go) | `netpoll` + goroutines | ~4 KB (goroutine stack) + GC metadata | Limited by GC throughput |
| telemt (Rust) | `epoll` (via Tokio) + futures | ~256 bytes (task state) + `Arc` overhead | Near kernel limit |

The C implementation has the lowest per-connection footprint because it uses
pre-allocated static pools and avoids heap allocation in the hot path. Rust is
close but Tokio's task abstraction adds per-task overhead. Go's goroutine
stacks (minimum 4 KB each, growing dynamically) make it the most memory-hungry
under high connection counts.

### Latency

- **C (this fork):** Deterministic. `epoll_wait` → `readv` → AES decrypt →
  forward → AES encrypt → `writev`. No allocator or GC in the fast path.
- **Go (mtg):** Generally low, but GC "stop-the-world" pauses (typically < 1 ms
  with Go 1.21+) cause p99 latency spikes under sustained load.
- **Rust (telemt):** Deterministic like C, but Tokio's waker/poll mechanism adds
  a small constant overhead per I/O operation. In practice, indistinguishable
  from C for proxy workloads.

### Scalability

| Metric | This fork (C) | mtg (Go) | telemt (Rust) |
|--------|:---:|:---:|:---:|
| 10K connections | ✅ | ✅ | ✅ |
| 100K connections | ✅ (multi-worker) | ⚠️ (GC pressure) | ✅ |
| Multi-core utilisation | `fork()` workers | Automatic (GOMAXPROCS) | Automatic (Tokio threadpool) |
| Zero-copy I/O | Yes (`readv`/`writev`) | No (Go copies to userspace) | Partial (`bytes::BytesMut`) |

---

## 4. Safety & Security Comparison

| Feature | This fork (C) | mtg (Go) | telemt (Rust) |
|---------|:---:|:---:|:---:|
| Memory safety | Manual ⚠️ | GC ✅ | Compile-time ✅ |
| Constant-time HMAC | Yes ✅ | N/A (Go `crypto/hmac` is constant-time) | Yes ✅ |
| Anti-replay protection | Strong (2-min window) ✅ | Strong ✅ | Partial ⚠️ |
| Privilege dropping | `setuid`/`setgid` ✅ | Runs as non-root ✅ | Runs as non-root ✅ |
| Fuzz testing (CI) | libFuzzer + ASan + UBSan ✅ | No ❌ | Partial ⚠️ |
| Static analysis (CI) | cppcheck + CodeQL ✅ | `go vet` + `staticcheck` ✅ | `clippy` ⚠️ |
| E2E tests (real clients) | Telethon ✅ | No ❌ | No ❌ |
| Heap overflow history | Yes (fixed) ⚠️ | None known ✅ | None known ✅ |
| IP ACL (blocklist/allowlist) | Yes ✅ | Yes ✅ | No ❌ |
| Per-secret connection limits | Yes ✅ | No ❌ | No ❌ |
| Seccomp / sandbox | No ❌ | No ❌ | No ❌ |

**Key safety observations:**

1. **This fork's C code has had real bugs** (heap overflow in `CONN_INFO`, UAF
   in buffer cleanup), but all were caught and fixed — many by the CI pipeline
   (ASan, `-Werror`, fuzz testing). The mitigation strategy (aggressive testing)
   is effective but reactive.

2. **Go and Rust eliminate entire bug classes** at the language level. Go prevents
   buffer overflows via bounds-checked slices; Rust prevents both overflows and
   data races via the borrow checker.

3. **This fork leads in testing rigour**: libFuzzer harnesses for TLS/HTTP
   parsers, AddressSanitizer CI, CodeQL security scanning, and real Telethon
   E2E tests — none of the alternatives match this coverage.

---

## 5. Suggested Winning Architecture

Based on the analysis above, the ideal MTProxy architecture would combine:

### Language: Rust

**Rationale:** Rust provides C-level performance without the memory safety risks
that have historically affected this codebase. The borrow checker eliminates
buffer overflows, use-after-free, and data races at compile time — the exact bug
classes found in the C codebase's history. Unlike Go, Rust has no garbage
collector, delivering the same predictable latency as C.

### I/O Model: `io_uring` with fallback to `epoll`

**Rationale:** Linux `io_uring` (available since kernel 5.1) provides
zero-copy, zero-syscall I/O submission via shared ring buffers. For a proxy
that forwards millions of packets, eliminating `read`/`write` syscall overhead
is a meaningful win. Libraries like `tokio-uring` or `glommio` provide
ergonomic Rust APIs. Fall back to `epoll` (via Tokio) on older kernels for
broad compatibility.

### Concurrency: Async tasks on a work-stealing threadpool

**Rationale:** Tokio's multi-threaded runtime automatically balances connections
across all available cores without the complexity of `fork()`-based multi-worker
coordination. Each connection is a lightweight async task (~256 bytes vs 4 KB
goroutine stack), enabling 100K+ concurrent connections per process.

### Buffer Management: Zero-copy `bytes::BytesMut` with pool

**Rationale:** Pre-allocate a pool of `BytesMut` buffers (similar to this fork's
`raw_message` linked-list design) to avoid per-packet heap allocation. Use
`Bytes` (reference-counted, immutable) for shared forwarding without copies.

### Crypto: `ring` or `aws-lc-rs` for AES-256, with OpenSSL as fallback

**Rationale:** The `ring` crate provides constant-time, audited AES-GCM/AES-CTR
implementations. For AES-IGE (required by MTProto), a thin wrapper over
`ring`'s AES primitives or OpenSSL's EVP API (via `openssl` crate) is needed.
`aws-lc-rs` is the FIPS-validated alternative.

### Recommended Internal Design

```
┌─────────────────────────────────────────────────────────┐
│                    mtproxy-rs                            │
├─────────────────────────────────────────────────────────┤
│  Acceptor                                               │
│  ├─ TcpListener (tokio)                                 │
│  ├─ TLS detection (parse ClientHello SNI)               │
│  └─ IP ACL check (blocklist / allowlist)                │
├─────────────────────────────────────────────────────────┤
│  Connection Handler (one async task per client)          │
│  ├─ Handshake: obfuscated2 or fake-TLS                  │
│  ├─ Secret validation (constant-time HMAC)              │
│  ├─ Anti-replay check (sliding window, 2-min TTL)       │
│  ├─ Reader task ←── client bytes ──→ AES decrypt        │
│  └─ Writer task ←── DC bytes ──→ AES encrypt + DRS      │
├─────────────────────────────────────────────────────────┤
│  DC Connector                                           │
│  ├─ Connection pool per datacenter                      │
│  ├─ Direct-to-DC or relay mode                          │
│  ├─ DH-2048 key exchange                                │
│  └─ Optional SOCKS5 upstream                            │
├─────────────────────────────────────────────────────────┤
│  DPI Evasion                                            │
│  ├─ Dynamic Record Sizing (three-phase ramp)            │
│  ├─ Weibull-distributed inter-record delays             │
│  └─ TCP splitting (custom TLS backend)                  │
├─────────────────────────────────────────────────────────┤
│  Observability                                          │
│  ├─ Prometheus /metrics endpoint                        │
│  ├─ Per-secret labelled gauges                          │
│  ├─ HTTP stats endpoint                                 │
│  └─ Structured logging (tracing crate)                  │
├─────────────────────────────────────────────────────────┤
│  Management                                             │
│  ├─ Multiple secrets with labels + connection limits    │
│  ├─ Atomic config reload (SIGHUP)                       │
│  ├─ Privilege dropping (setuid after bind)              │
│  └─ Health check endpoint                               │
└─────────────────────────────────────────────────────────┘
```

### Why Not Just Use telemt?

telemt is the closest to this ideal, but it currently lacks:

- **Fuzz testing and E2E test infrastructure** (this fork leads here).
- **Dynamic Record Sizing + timing mimicry** (this fork and mtg have it;
  telemt does not).
- **Strong anti-replay** (telemt's protection is partial).
- **Per-secret connection limits** for abuse prevention.
- **The production mileage** of the C codebase (derived from Telegram's own code).

### Pragmatic Recommendation

For **this project today**, the most effective path is to continue improving
the C codebase with its strong CI pipeline (fuzz testing, ASan, CodeQL) rather
than rewriting in Rust. The safety gap is largely closed by tooling:

1. **AddressSanitizer** catches heap overflows and use-after-free in CI.
2. **libFuzzer** continuously tests parsers with random input.
3. **CodeQL** detects security anti-patterns statically.
4. **`-Werror` CI** catches undefined behaviour from compiler warnings.
5. **Telethon E2E tests** validate real-world protocol correctness.

A Rust rewrite becomes compelling when:
- The feature set stabilises and the maintenance burden shifts from features to
  bug fixes.
- `io_uring` support in Rust matures (2025–2026 timeline).
- A contributor with Rust + async networking expertise is available.

---

## Summary

| Dimension | Winner | Runner-up |
|-----------|--------|-----------|
| **Raw performance** | This fork (C) — zero overhead, static pools | telemt (Rust) — near-C, no GC |
| **Memory safety** | telemt (Rust) — compile-time guarantees | mtg (Go) — GC-safe |
| **Testing rigour** | This fork (C) — fuzz + ASan + E2E + CodeQL | mtg (Go) — basic CI |
| **Feature completeness** | telemt (Rust) — REST API, per-user limits | This fork (C) — DRS + timing mimicry |
| **DPI resistance** | This fork (C) — DRS + Weibull delays | mtg (Go) — DRS |
| **Ease of deployment** | mtg (Go) — single binary, minimal config | This fork (C) — static binaries + Docker + RPM |
| **Ideal new architecture** | **Rust + Tokio + io_uring** | C + epoll (current, proven) |
