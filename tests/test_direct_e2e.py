#!/usr/bin/env python3
"""E2E tests for MTProxy direct mode.

Starts a real Telethon session through a direct-mode MTProxy and calls
get_me() to verify the full data path works.  Tests both obfuscated2
(dd-prefix) and fake-TLS (ee-prefix) transport modes.

Requires the TG_STRING_SESSION environment variable (Telethon StringSession).
Skips gracefully when the secret is absent (fork PRs, external contributors).

Usage:
    TG_STRING_SESSION=... MTPROXY_SECRET=... python3 tests/test_direct_e2e.py

Environment variables:
    TG_STRING_SESSION   Telethon StringSession string (required)
    MTPROXY_SECRET      32-char hex proxy secret (required)
    DIRECT_HOST         Proxy hostname (default: localhost)
    DIRECT_OBFS2_PORT   Obfuscated2 proxy port (default: 8443)
    DIRECT_TLS_PORT     Fake-TLS proxy port (default: 9443)
    EE_DOMAIN           Domain for fake-TLS mode (default: ya.ru)
"""

import asyncio
import os
import sys

# Official Telegram macOS client credentials (public, well-known).
API_ID = 2834
API_HASH = "68875f756c9b437a8b916ca3de215815"


def _patch_telethon_faketls():
    """Patch TelethonFakeTLS bugs.

    1. read_server_hello: upstream only reads the first encrypted record,
       but the proxy computes HMAC over all records.
    2. FakeTLSStreamWriter: upstream never sends CCS (ChangeCipherSpec)
       before the first data record, but the proxy requires it.
    """
    import TelethonFakeTLS.FakeTLS.TLSInOut as tls_io

    async def _read_server_hello(self):
        buf = bytearray(await self.upstream.readexactly(133))
        while True:
            try:
                header = await asyncio.wait_for(
                    self.upstream.readexactly(5), timeout=0.5
                )
            except (asyncio.TimeoutError, EOFError):
                break
            buf += header
            if header[:3] != b"\x17\x03\x03":
                break
            rec_len = int.from_bytes(header[3:5], "big")
            buf += await self.upstream.readexactly(rec_len)
        return bytes(buf)

    tls_io.FakeTLSStreamReader.read_server_hello = _read_server_hello

    _orig_write = tls_io.FakeTLSStreamWriter.write
    _ccs_sent_writers = set()

    def _writer_write_with_ccs(self, data, extra={}):
        if id(self) not in _ccs_sent_writers:
            _ccs_sent_writers.add(id(self))
            self.upstream.write(b"\x14\x03\x03\x00\x01\x01")
        return _orig_write(self, data, extra)

    tls_io.FakeTLSStreamWriter.write = _writer_write_with_ccs


async def test_obfs2_get_me(host, port, secret, session_str):
    """Connect via obfuscated2 (dd-prefix) and call get_me()."""
    from telethon import TelegramClient
    from telethon.network.connection import (
        ConnectionTcpMTProxyRandomizedIntermediate,
    )
    from telethon.sessions import StringSession

    print(f"[obfs2] Connecting to {host}:{port} ...", flush=True)

    client = TelegramClient(
        StringSession(session_str),
        api_id=API_ID,
        api_hash=API_HASH,
        connection=ConnectionTcpMTProxyRandomizedIntermediate,
        proxy=(host, port, "dd" + secret),
    )

    try:
        await asyncio.wait_for(client.connect(), timeout=30)
        if not client.is_connected():
            print("[obfs2] FAIL: client did not connect")
            return False

        me = await asyncio.wait_for(client.get_me(), timeout=15)
        if me is None:
            print("[obfs2] FAIL: get_me() returned None")
            return False

        print(f"[obfs2] OK: get_me() returned user_id={me.id}")
        return True
    except Exception as e:
        print(f"[obfs2] FAIL: {type(e).__name__}: {e}")
        return False
    finally:
        try:
            await client.disconnect()
        except Exception:
            pass


async def test_faketls_get_me(host, port, secret, domain, session_str):
    """Connect via fake-TLS (ee-prefix) and call get_me()."""
    try:
        from TelethonFakeTLS import ConnectionTcpMTProxyFakeTLS
    except ImportError:
        print("[fake-tls] SKIP: TelethonFakeTLS not installed")
        return True

    from telethon import TelegramClient
    from telethon.sessions import StringSession

    _patch_telethon_faketls()

    proxy_secret = secret + domain.encode().hex()
    print(f"[fake-tls] Connecting to {host}:{port} (domain={domain}) ...",
          flush=True)

    client = TelegramClient(
        StringSession(session_str),
        api_id=API_ID,
        api_hash=API_HASH,
        connection=ConnectionTcpMTProxyFakeTLS,
        proxy=(host, port, proxy_secret),
    )

    try:
        await asyncio.wait_for(client.connect(), timeout=30)
        if not client.is_connected():
            print("[fake-tls] FAIL: client did not connect")
            return False

        me = await asyncio.wait_for(client.get_me(), timeout=15)
        if me is None:
            print("[fake-tls] FAIL: get_me() returned None")
            return False

        print(f"[fake-tls] OK: get_me() returned user_id={me.id}")
        return True
    except Exception as e:
        print(f"[fake-tls] FAIL: {type(e).__name__}: {e}")
        return False
    finally:
        try:
            await client.disconnect()
        except Exception:
            pass


def main():
    session_str = os.environ.get("TG_STRING_SESSION", "")
    if not session_str:
        print("SKIP: TG_STRING_SESSION not set (secrets not available)")
        sys.exit(0)

    secret = os.environ.get("MTPROXY_SECRET", "")
    if not secret:
        print("ERROR: MTPROXY_SECRET required")
        sys.exit(1)

    host = os.environ.get("DIRECT_HOST", "localhost")
    obfs2_port = int(os.environ.get("DIRECT_OBFS2_PORT", "8443"))
    tls_port = int(os.environ.get("DIRECT_TLS_PORT", "9443"))
    domain = os.environ.get("EE_DOMAIN", "ya.ru")

    results = []

    print("=== Direct Mode E2E Tests ===\n")

    # Test 1: obfuscated2
    ok = asyncio.run(test_obfs2_get_me(host, obfs2_port, secret, session_str))
    results.append(("obfs2", ok))
    print()

    # Test 2: fake-TLS
    ok = asyncio.run(
        test_faketls_get_me(host, tls_port, secret, domain, session_str)
    )
    results.append(("fake-tls", ok))

    print("\n=== Results ===")
    all_ok = True
    for name, ok in results:
        status = "PASS" if ok else "FAIL"
        print(f"  {name}: {status}")
        if not ok:
            all_ok = False

    sys.exit(0 if all_ok else 1)


if __name__ == "__main__":
    main()
