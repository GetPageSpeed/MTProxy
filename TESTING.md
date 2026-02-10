# Testing MTProxy

This repository includes a test suite to verify the functionality of the MTProxy server. The tests run in Docker or directly on the host and check:

1. **HTTP Stats**: Verifies the stats endpoint (port 8888) is accessible.
2. **MTProto Port**: Verifies the MTProto port accepts TCP connections.

## Prerequisites

- Docker and Docker Compose (for containerized testing)
- `make` (for running the test command)
- Python 3.9+ (for local script execution without Docker)

## Running Tests

### Using Make (Docker)

Simply run:

```bash
make test
```

This will:
1. Build the MTProxy Docker image.
2. Build the test runner Docker image.
3. Start the proxy and test runner.
4. Execute the connectivity checks.

A random secret will be generated automatically if `MTPROXY_SECRET` is not set.

### Running Locally (No Docker)

If you want to run the tests against a local instance:

1. Install Python dependencies:
   ```bash
   pip install -r tests/requirements.txt
   ```
2. Set environment variables:
   ```bash
   export MTPROXY_HOST=localhost  # or IP of your proxy
   export MTPROXY_PORT=443        # or your proxy port
   ```
3. Run the script:
   ```bash
   python3 tests/test_proxy.py
   ```

## Manual Connectivity Check

If tests are failing, you can manually verify connectivity to Telegram servers:

```bash
# Check connectivity to Telegram DC 2 (Europe)
nc -zv 149.154.167.50 443
# Expected output: Connection to 149.154.167.50 443 port [tcp/https] succeeded!
```

If this fails, your network (ISP, firewall, or hosting provider) is blocking connections to Telegram.

## Troubleshooting

- **Timeout**: If tests time out, check your network connection. MTProto proxies may be blocked by some ISPs.
- **Port already in use**: The tests use ports 18443 and 18888 by default. Make sure these are available.
