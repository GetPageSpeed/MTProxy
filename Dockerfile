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
RUN make clean && make -j$(nproc)

# Runtime image (must match builder architecture)
FROM --platform=linux/amd64 ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libssl3 \
    zlib1g \
    curl \
    ca-certificates \
    vim-common \
    && rm -rf /var/lib/apt/lists/*

# Create user for running the proxy
RUN useradd -r -s /bin/false mtproxy

# Create directory for the application
WORKDIR /opt/mtproxy

# Copy binary from builder stage
COPY --from=builder /src/objs/bin/mtproto-proxy /opt/mtproxy/

# Make binary executable
RUN chmod +x /opt/mtproxy/mtproto-proxy

# Expose ports
EXPOSE 443 8888

# Add startup script
COPY <<EOF /opt/mtproxy/start.sh
#!/bin/bash
set -e

# Download proxy secret if not exists
if [ ! -f proxy-secret ]; then
    echo "Downloading proxy secret..."
    curl -s https://core.telegram.org/getProxySecret -o proxy-secret
fi

# Download proxy config if not exists or older than 1 day
if [ ! -f proxy-multi.conf ] || [ \$(find proxy-multi.conf -mtime +1 | wc -l) -gt 0 ]; then
    echo "Downloading proxy config..."
    curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf
fi

# Generate secret if not provided
if [ -z "\$SECRET" ]; then
    echo "No SECRET provided, generating one..."
    export SECRET=\$(head -c 16 /dev/urandom | xxd -ps)
    echo "Generated secret: \$SECRET"
fi

# Set default values
PORT=\${PORT:-443}
STATS_PORT=\${STATS_PORT:-8888}
WORKERS=\${WORKERS:-1}
PROXY_TAG=\${PROXY_TAG:-}
RANDOM_PADDING=\${RANDOM_PADDING:-}
# Max connections - lower value avoids rlimit issues in containers
MAX_CONNECTIONS=\${MAX_CONNECTIONS:-60000}

# Detect container-local IPv4 for NAT (used when EXTERNAL_IP is provided).
LOCAL_IP=\$(grep -vE '(local|ip6|^fd)' /etc/hosts | awk 'NR==1 {print \$1}')

# Optional public IPv4 address to advertise to Telegram DCs; pass via -e EXTERNAL_IP=1.2.3.4
EXTERNAL_IP=\${EXTERNAL_IP:-}

NAT_INFO_ARGS=""
if [ -n "\$EXTERNAL_IP" ] && [ -n "\$LOCAL_IP" ]; then
    NAT_INFO_ARGS="--nat-info \$LOCAL_IP:\$EXTERNAL_IP"
fi

# Build command
CMD="./mtproto-proxy -p \$STATS_PORT -H \$PORT -S \$SECRET -c \$MAX_CONNECTIONS --http-stats \$NAT_INFO_ARGS"

if [ -n "\$PROXY_TAG" ]; then
    CMD="\$CMD -P \$PROXY_TAG"
fi

if [ "\$RANDOM_PADDING" = "true" ]; then
    CMD="\$CMD -R"
fi

CMD="\$CMD --aes-pwd proxy-secret proxy-multi.conf -M \$WORKERS -u mtproxy \$@"

echo "Starting MTProxy with command: \$CMD"
exec \$CMD
EOF

RUN chmod +x /opt/mtproxy/start.sh

# Set entrypoint
ENTRYPOINT ["/opt/mtproxy/start.sh"] 