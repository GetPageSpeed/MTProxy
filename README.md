# MTProxy by GetPageSpeed

Simple MT-Proto proxy.

**This is a fork of MTProxy which includes various improvements and fixes that upstream has not merged due to abandonding their repository.
Most of these fixes aim for stable running of MTProxy in production without surprises.**

> [!TIP]
> Chỉ cần copy và paste đoạn này vào “Saved Messages” của bạn, gửi cho chính bạn, và click vào link trong Telegram để thiết lập proxy:

```
tg://proxy?server=mtproxy.getpagespeed.com&port=8444&secret=d7f04aa6631130af1a153e7a5e12c291
```

## Install

### Quick Install (Recommended)

For the easiest installation with prebuilt RPM packages, automatic updates, and complete configuration:

**👉 [GetPageSpeed MTProxy Installation Guide](https://www.getpagespeed.com/server-setup/mtproxy)**

This includes:
- One-command installation via RPM repository
- Automatic configuration file generation
- SystemD service setup
- Firewall configuration
- Fake TLS setup instructions

### Manual Build (Advanced)


## Building
Install dependencies, you would need common set of tools for building from source, and development packages for `openssl` and `zlib`.

On Debian/Ubuntu:
```bash
apt install git curl build-essential libssl-dev zlib1g-dev
```
On CentOS/RHEL (not advisable, use packages mentioned above instead):
```bash
yum install openssl-devel zlib-devel
yum groupinstall "Development Tools"
```

Clone the repo:
```bash
git clone https://github.com/GetPageSpeed/MTProxy
cd MTProxy
```

To build, simply run `make`, the binary will be in `objs/bin/mtproto-proxy`:

```bash
make && cd objs/bin
```

If the build has failed, you should run `make clean` before building it again.

## Running
1. Obtain a secret, used to connect to telegram servers.
```bash
curl -s https://core.telegram.org/getProxySecret -o proxy-secret
```
2. Obtain current telegram configuration. It can change (occasionally), so we encourage you to update it once per day.
```bash
curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf
```
3. Generate a secret to be used by users to connect to your proxy.
```bash
head -c 16 /dev/urandom | xxd -ps
```
4. Run `mtproto-proxy`:
```bash
./mtproto-proxy -u nobody -p 8888 -H 443 -S <secret> --aes-pwd proxy-secret proxy-multi.conf -M 1
```
... where:
- `nobody` is the username. `mtproto-proxy` calls `setuid()` to drop privilegies.
- `443` is the port, used by clients to connect to the proxy.
- `8888` is the local port. You can use it to get statistics from `mtproto-proxy`. Like `wget localhost:8888/stats`. You can only get this stat via loopback.
- `<secret>` is the secret generated at step 3. Also you can set multiple secrets: `-S <secret1> -S <secret2>`.
- `proxy-secret` and `proxy-multi.conf` are obtained at steps 1 and 2.
- `1` is the number of workers. You can increase the number of workers, if you have a powerful server.

Also feel free to check out other options using `mtproto-proxy --help`.

5. Generate the link with following schema: `tg://proxy?server=SERVER_NAME&port=PORT&secret=SECRET` (or let the official bot generate it for you).
6. Register your proxy with [@MTProxybot](https://t.me/MTProxybot) on Telegram.
7. Set received tag with arguments: `-P <proxy tag>`
8. Enjoy.

## Transport Modes and Secret Prefixes

MTProxy supports different transport modes that provide various levels of obfuscation:

> 💡 **For complete setup instructions including RPM packages**, see the [GetPageSpeed MTProxy installation guide](https://www.getpagespeed.com/server-setup/mtproxy)

### DD Mode (Random Padding)
Due to some ISPs detecting MTProxy by packet sizes, random padding is added to packets when this mode is enabled.

**Client Setup**: Add `dd` prefix to secret (`cafe...babe` => `ddcafe...babe`)

**Server Setup**: Use `-R` argument to allow only clients with random padding enabled

> 📖 **See also**: [GetPageSpeed guide - DD mode setup](https://www.getpagespeed.com/server-setup/mtproxy)

### EE Mode (Fake-TLS + Padding)

EE mode provides enhanced obfuscation by mimicking TLS 1.3 connections, making MTProxy traffic harder to detect and block.

**Server Setup**:
1. **Add domain configuration**: Choose a website that supports TLS 1.3 (e.g., `www.google.com`, `www.cloudflare.com`)
   ```bash
   ./mtproto-proxy -u nobody -p 8888 -H 443 -S <secret> -D www.google.com --aes-pwd proxy-secret proxy-multi.conf -M 1
   ```

2. **Get domain HEX dump**:
   ```bash
   echo -n www.google.com | xxd -plain
   # Output: 7777772e676f6f676c652e636f6d
   ```

**Client Setup**:
Use the format: `ee` + server_secret + domain_hex

**Example**:
- Server secret: `cafe1234567890abcdef1234567890ab`
- Domain: `www.google.com` 
- Domain HEX: `7777772e676f6f676c652e636f6d`
- **Client secret**: `eecafe1234567890abcdef1234567890ab7777772e676f6f676c652e636f6d`

**Quick Generation**:
```bash
# Generate complete client secret automatically
SECRET="cafe1234567890abcdef1234567890ab"
DOMAIN="www.google.com"
echo -n "ee${SECRET}" && echo -n $DOMAIN | xxd -plain
```

**Benefits**:
- ✅ **Traffic appears as TLS 1.3**: Harder to detect and block
- ✅ **Works with modern clients**: Desktop, mobile, and web clients
- ✅ **Domain flexibility**: Choose any TLS 1.3-capable domain
- ✅ **Better censorship resistance**: More sophisticated obfuscation

> 📖 **Complete Fake TLS setup guide**: [GetPageSpeed MTProxy - Fake TLS section](https://www.getpagespeed.com/server-setup/mtproxy#fake-tls)

## Systemd example configuration
1. Create systemd service file (it's standard path for the most Linux distros, but you should check it before):
```bash
nano /etc/systemd/system/MTProxy.service
```
2. Edit this basic service (especially paths and params):
```bash
[Unit]
Description=MTProxy
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/MTProxy
ExecStart=/opt/MTProxy/mtproto-proxy -u nobody -p 8888 -H 443 -S <secret> -P <proxy tag> <other params>
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
3. Reload daemons:
```bash
systemctl daemon-reload
```
4. Test fresh MTProxy service:
```bash
systemctl restart MTProxy.service
# Check status, it should be active
systemctl status MTProxy.service
```
5. Enable it, to autostart service after reboot:
```bash
systemctl enable MTProxy.service
```

## Docker

### Using Pre-built Docker Image

The easiest way to run MTProxy is using our pre-built Docker image from GitHub Container Registry:

```bash
docker run -d \
  --name mtproxy \
  -p 443:443 \
  -p 8888:8888 \
  -e SECRET=$(head -c 16 /dev/urandom | xxd -ps) \
  -e PROXY_TAG=your_proxy_tag_here \
  -v mtproxy-data:/opt/mtproxy/data \
  --restart unless-stopped \
  --platform linux/amd64 \
  ghcr.io/getpagespeed/mtproxy:latest
```

#### Environment Variables

- `SECRET`: User secret for proxy connections (auto-generated if not provided)
  - **For DD mode**: Use `dd` + 32 hex digits (e.g., `ddcafe1234567890abcdef1234567890`)
  - **For EE mode**: Use `ee` + 32 hex digits + domain hex (e.g., `eecafe1234567890abcdef1234567890ab7777772e676f6f676c652e636f6d`)
  - **Standard mode**: Just 32 hex digits without prefix
- `PORT`: Port for client connections (default: 443)
- `STATS_PORT`: Port for statistics endpoint (default: 8888)
- `WORKERS`: Number of worker processes (default: 1)
- `PROXY_TAG`: Proxy tag from [@MTProxybot](https://t.me/MTProxybot)
- `RANDOM_PADDING`: Enable random padding only mode (true/false, default: false)

#### Getting Statistics

```bash
curl http://localhost:8888/stats
```

### Using Docker Compose

Create a `.env` file:
```bash
SECRET=your_secret_here
PROXY_TAG=your_proxy_tag_here
RANDOM_PADDING=false
```

Then run:
```bash
docker-compose up -d
```

### Building Your Own Image

If you want to build the image yourself:

```bash
docker build -t mtproxy .
docker run -d \
  --name mtproxy \
  -p 443:443 \
  -p 8888:8888 \
  -e SECRET=your_secret_here \
  mtproxy
```

### Health Check

The Docker container includes a health check that monitors the statistics endpoint. You can check the container health with:

```bash
docker ps
# Look for the health status in the STATUS column
```

### Volume Mounting

The container persists configuration files in `/opt/mtproxy/data`. Mount a volume to persist data across container restarts:

```bash
-v /path/to/host/data:/opt/mtproxy/data
```

### Available Tags

- `ghcr.io/getpagespeed/mtproxy:latest` - Latest stable build from master branch
- `ghcr.io/getpagespeed/mtproxy:master` - Latest build from master branch
- `ghcr.io/getpagespeed/mtproxy:v*` - Specific version tags (when available)
