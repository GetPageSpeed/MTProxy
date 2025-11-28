import socket
import time
import requests
import sys
import os

def test_http_stats():
    """Test that the HTTP stats endpoint is accessible."""
    print("Testing HTTP stats...")
    host = os.environ.get("MTPROXY_HOST", "mtproxy")
    stats_port = os.environ.get("MTPROXY_STATS_PORT", "8888")
    url = f"http://{host}:{stats_port}/stats"
    try:
        ip = socket.gethostbyname(host)
        print(f"Resolved {host} to {ip}")
    except Exception as e:
        print(f"Could not resolve {host}: {e}")

    for i in range(5):
        try:
            response = requests.get(url, timeout=3)
            if response.status_code == 200:
                print(f"HTTP stats OK: {response.text[:50]}...")
                return True
            else:
                print(f"HTTP stats failed: {response.status_code}")
        except Exception as e:
            print(f"HTTP stats exception (attempt {i+1}): {e}")
        time.sleep(1)
    return False

def test_mtproto_port():
    """Test that the MTProto port accepts TCP connections."""
    print("Testing MTProto port...")
    host = os.environ.get("MTPROXY_HOST", "mtproxy")
    port = int(os.environ.get("MTPROXY_PORT", 443))
    try:
        ip = socket.gethostbyname(host)
        print(f"Connecting to {ip}:{port}")
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(5)
        s.connect((ip, port))
        s.close()
        print("MTProto port OK")
        return True
    except Exception as e:
        print(f"MTProto port exception: {e}")
        return False

def check_upstream_connectivity():
    """Check if we can connect to Telegram's DCs (informational only)."""
    targets = [
        ("149.154.167.50", 443),
        ("149.154.167.50", 8888),
        ("91.108.4.166", 8888)
    ]
    
    for dc_ip, dc_port in targets:
        print(f"Checking upstream connectivity to Telegram DC {dc_ip}:{dc_port}...")
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(5)
            s.connect((dc_ip, dc_port))
            s.close()
            print(f"Upstream connectivity to Telegram DC {dc_ip}:{dc_port} OK")
        except Exception as e:
            print(f"WARNING: Could not connect to Telegram DC {dc_ip}:{dc_port}: {e}")
            print("This indicates a network issue (ISP blocking, firewall, etc.)")
            if dc_port == 8888:
                print("MTProxy often uses port 8888 to connect to DCs. If this is blocked, proxy will fail.")

if __name__ == "__main__":
    print("Starting tests...", flush=True)
    
    # Check upstream connectivity first (informational)
    check_upstream_connectivity()

    # Give the proxy time to start
    time.sleep(5)
    
    stats_ok = test_http_stats()
    mtproto_ok = test_mtproto_port()

    # MTProto port is the core test - it must work
    if mtproto_ok:
        if not stats_ok:
            print("WARNING: HTTP stats failed, but MTProto port is OK.")
        print("Tests passed!")
        sys.exit(0)
    else:
        print("Tests failed! MTProto port not accessible.")
        sys.exit(1)
