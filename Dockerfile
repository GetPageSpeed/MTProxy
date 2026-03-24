# Use Ubuntu as base image for building (force x86_64 for intrinsics support)
FROM --platform=linux/amd64 ubuntu:22.04 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /src

# Copy source code
COPY . .

# Build the application
ARG VERSION=unknown
RUN make clean && make -j$(nproc) EXTRA_VERSION="${VERSION}"

# Runtime image (must match builder architecture)
FROM --platform=linux/amd64 ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libssl3 \
    zlib1g \
    curl \
    ca-certificates \
    vim-common \
    cron \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Create user for running the proxy
RUN useradd -r -s /bin/false mtproxy

# Create directory for the application
WORKDIR /opt/mtproxy

# Copy binary from builder stage
COPY --from=builder /src/objs/bin/mtproto-proxy /opt/mtproxy/

# Make binary executable
RUN chmod +x /opt/mtproxy/mtproto-proxy

# proxy-secret is a static public 128-byte blob used for MTProto key exchange.
# Baking it at build time eliminates the most critical runtime network dependency.
RUN curl --connect-timeout 10 --max-time 30 --retry 3 --retry-delay 2 \
    -fsSL https://core.telegram.org/getProxySecret -o /opt/mtproxy/proxy-secret

# Create data directory for persistent config (proxy-multi.conf)
RUN mkdir -p /opt/mtproxy/data

# Install cron job to refresh proxy-multi.conf from Telegram servers every 6 hours.
# Prevents proxy from becoming unavailable due to stale DC configuration.
# Output is redirected to PID 1's stdout so it appears in `docker logs`.
COPY mtproxy-config-refresh.sh /opt/mtproxy/config-refresh.sh
RUN chmod +x /opt/mtproxy/config-refresh.sh \
    && echo '0 */6 * * * root /opt/mtproxy/config-refresh.sh >> /proc/1/fd/1 2>> /proc/1/fd/2' > /etc/cron.d/mtproxy-config-refresh \
    && chmod 0644 /etc/cron.d/mtproxy-config-refresh

# Expose ports
EXPOSE 443 8888

# Add startup script
COPY <<EOF /opt/mtproxy/start.sh
#!/bin/bash
set -e

# proxy-secret is baked into the image at build time
if [ ! -f proxy-secret ]; then
    echo "ERROR: proxy-secret not found. The Docker image may be corrupted." >&2
    exit 1
fi

# Download/refresh proxy config to data/ (persisted via volume mount)
CONFIG_PATH="data/proxy-multi.conf"
NEEDS_DOWNLOAD=0

if [ ! -f "\$CONFIG_PATH" ]; then
    NEEDS_DOWNLOAD=1
elif [ \$(find "\$CONFIG_PATH" -mtime +1 2>/dev/null | wc -l) -gt 0 ]; then
    NEEDS_DOWNLOAD=1
fi

if [ "\$NEEDS_DOWNLOAD" -eq 1 ]; then
    echo "Downloading proxy config..."
    if curl --connect-timeout 10 --max-time 30 --retry 3 --retry-delay 2 -fsSL https://core.telegram.org/getProxyConfig -o "\$CONFIG_PATH.tmp"; then
        mv "\$CONFIG_PATH.tmp" "\$CONFIG_PATH"
        echo "Proxy config downloaded successfully."
    else
        rm -f "\$CONFIG_PATH.tmp"
        if [ -f "\$CONFIG_PATH" ]; then
            echo "WARNING: Failed to refresh proxy config, using cached copy." >&2
        else
            echo "ERROR: Failed to download proxy config and no cached copy exists." >&2
            echo "Ensure core.telegram.org is reachable, or provide proxy-multi.conf in the data/ volume." >&2
            exit 1
        fi
    fi
fi

# Collect secrets from comma-separated SECRET and/or numbered SECRET_N vars
SECRETS=()

if [ -n "\$SECRET" ]; then
    IFS=',' read -ra _parts <<< "\$SECRET"
    for _s in "\${_parts[@]}"; do
        _s=\$(echo "\$_s" | tr -d '[:space:]')
        [ -n "\$_s" ] && SECRETS+=("\$_s")
    done
fi

for _i in \$(seq 1 16); do
    _var="SECRET_\${_i}"
    _val="\${!_var}"
    if [ -n "\$_val" ]; then
        _val=\$(echo "\$_val" | tr -d '[:space:]')
        SECRETS+=("\$_val")
    fi
done

if [ \${#SECRETS[@]} -eq 0 ]; then
    echo "No SECRET provided, generating one..."
    _gen=\$(head -c 16 /dev/urandom | xxd -ps)
    SECRETS+=("\$_gen")
    echo "Generated secret: \$_gen"
fi

if [ \${#SECRETS[@]} -gt 16 ]; then
    echo "ERROR: Maximum 16 secrets supported, got \${#SECRETS[@]}" >&2
    exit 1
fi

echo "Configured \${#SECRETS[@]} secret(s)"

# Set default values
PORT=\${PORT:-443}
STATS_PORT=\${STATS_PORT:-8888}
WORKERS=\${WORKERS:-1}
PROXY_TAG=\${PROXY_TAG:-}
RANDOM_PADDING=\${RANDOM_PADDING:-}
# Domain or host:port for TLS-transport mode (e.g. google.com or 127.0.0.1:8443)
EE_DOMAIN=\${EE_DOMAIN:-}
# Max connections - lower value avoids rlimit issues in containers
MAX_CONNECTIONS=\${MAX_CONNECTIONS:-60000}

# Detect container-local IPv4 for NAT.
LOCAL_IP=\$(ip -4 route get 8.8.8.8 2>/dev/null | grep -Po 'src \K[\d.]+' || grep -vE '(local|ip6|^fd|^\$)' /etc/hosts | awk 'NR==1 {print \$1}')

# Public IPv4 address to advertise to Telegram DCs.
# Auto-detected if not provided — required for Docker NAT to work.
EXTERNAL_IP=\${EXTERNAL_IP:-}
if [ -z "\$EXTERNAL_IP" ]; then
    EXTERNAL_IP=\$(curl -s -4 --connect-timeout 5 --max-time 10 https://icanhazip.com 2>/dev/null || curl -s -4 --connect-timeout 5 --max-time 10 https://ifconfig.me 2>/dev/null || true)
    if [ -n "\$EXTERNAL_IP" ]; then
        echo "Auto-detected external IP: \$EXTERNAL_IP"
    fi
fi

NAT_INFO_ARGS=""
if [ -n "\$EXTERNAL_IP" ] && [ -n "\$LOCAL_IP" ]; then
    NAT_INFO_ARGS="--nat-info \$LOCAL_IP:\$EXTERNAL_IP"
elif [ -z "\$EXTERNAL_IP" ]; then
    echo "WARNING: Could not detect external IP. Set EXTERNAL_IP env var for Docker NAT support." >&2
fi

# Build command
SECRET_ARGS=""
for _s in "\${SECRETS[@]}"; do
    SECRET_ARGS="\$SECRET_ARGS -S \$_s"
done

CMD="./mtproto-proxy -p \$STATS_PORT -H \$PORT\$SECRET_ARGS -c \$MAX_CONNECTIONS --http-stats --allow-skip-dh \$NAT_INFO_ARGS"

if [ -n "\$PROXY_TAG" ]; then
    CMD="\$CMD -P \$PROXY_TAG"
fi

if [ "\$RANDOM_PADDING" = "true" ]; then
    CMD="\$CMD -R"
fi

if [ -n "\$EE_DOMAIN" ]; then
    CMD="\$CMD -D \$EE_DOMAIN"
fi

CMD="\$CMD --aes-pwd proxy-secret data/proxy-multi.conf -M \$WORKERS -u mtproxy \$@"

echo "Starting MTProxy with command: \$CMD"

# Print ready-to-share connection links
echo ""
echo "===== Connection Links ====="
_host="\${EXTERNAL_IP:-<YOUR_SERVER_IP>}"
for _s in "\${SECRETS[@]}"; do
    if [ -n "\$EE_DOMAIN" ]; then
        _domain_only=\$(echo "\$EE_DOMAIN" | cut -d: -f1)
        _domain_hex=\$(printf '%s' "\$_domain_only" | xxd -ps | tr -d '\n')
        _full="ee\${_s}\${_domain_hex}"
    elif [ "\$RANDOM_PADDING" = "true" ]; then
        _full="dd\${_s}"
    else
        _full="\$_s"
    fi
    echo "https://t.me/proxy?server=\${_host}&port=\${PORT}&secret=\${_full}"
done
if [ "\$_host" = "<YOUR_SERVER_IP>" ]; then
    echo "(Set EXTERNAL_IP to show your server's IP)"
fi
echo "============================="
echo ""

# Start cron daemon for daily config refresh
cron

exec \$CMD
EOF

RUN chmod +x /opt/mtproxy/start.sh

HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
    CMD curl -f http://localhost:8888/stats || exit 1

# Set entrypoint
ENTRYPOINT ["/opt/mtproxy/start.sh"] 