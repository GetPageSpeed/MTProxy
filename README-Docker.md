# MTProxy Docker Setup

This repository provides a Docker image for MTProxy that is automatically built using GitHub Actions.

## Quick Start

### Using Pre-built Image

The easiest way to get started is using the pre-built image from GitHub Container Registry:

```bash
# Generate a secret
SECRET=$(head -c 16 /dev/urandom | xxd -ps)

# Run the container
docker run -d \
  --name mtproxy \
  -p 443:443 \
  -p 8888:8888 \
  -e SECRET=$SECRET \
  ghcr.io/getpagespeed/mtproxy:latest

# Get the connection URL
echo "Connection URL: tg://proxy?server=YOUR_SERVER_IP&port=443&secret=$SECRET"
```

### Using Docker Compose

1. Clone this repository:
```bash
git clone https://github.com/GetPageSpeed/MTProxy.git
cd MTProxy
```

2. Create a `.env` file:
```bash
# Generate a secret
SECRET=$(head -c 16 /dev/urandom | xxd -ps)
echo "SECRET=$SECRET" > .env
```

3. Start the service:
```bash
docker-compose up -d
```

4. Check the logs to see the generated secret (if not provided):
```bash
docker-compose logs mtproxy
```

## Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `SECRET` | Client connection secret | Auto-generated | No |
| `PORT` | Client connection port | 443 | No |
| `STATS_PORT` | Statistics port | 8888 | No |
| `WORKERS` | Number of worker processes | 1 | No |
| `PROXY_TAG` | Proxy tag from @MTProxybot | None | No |
| `RANDOM_PADDING` | Enable random padding (true/false) | false | No |

## Advanced Configuration

### Multiple Secrets

You can provide multiple secrets by setting the `SECRET` environment variable with space-separated values:

```bash
docker run -d \
  --name mtproxy \
  -p 443:443 \
  -e SECRET="secret1 secret2 secret3" \
  ghcr.io/getpagespeed/mtproxy:latest
```

### Random Padding

To enable random padding (helps bypass some ISP detection):

```bash
docker run -d \
  --name mtproxy \
  -p 443:443 \
  -e SECRET="dd$(head -c 16 /dev/urandom | xxd -ps)" \
  -e RANDOM_PADDING=true \
  ghcr.io/getpagespeed/mtproxy:latest
```

### Proxy Registration

1. Start your proxy
2. Register with [@MTProxybot](https://t.me/MTProxybot) on Telegram
3. Get your proxy tag and add it to the environment:

```bash
docker run -d \
  --name mtproxy \
  -p 443:443 \
  -e SECRET="your_secret" \
  -e PROXY_TAG="your_proxy_tag" \
  ghcr.io/getpagespeed/mtproxy:latest
```

## Building Locally

To build the image yourself:

```bash
git clone https://github.com/GetPageSpeed/MTProxy.git
cd MTProxy
docker build -t mtproxy .
```

## Monitoring

### Health Check

The container includes a health check that monitors the statistics endpoint:

```bash
docker ps  # Check health status
```

### Statistics

Access statistics at `http://localhost:8888/stats` or:

```bash
curl http://localhost:8888/stats
```

## Persistent Data

To persist configuration files across container restarts:

```bash
docker run -d \
  --name mtproxy \
  -p 443:443 \
  -p 8888:8888 \
  -v ./data:/opt/mtproxy/data \
  -e SECRET="your_secret" \
  ghcr.io/getpagespeed/mtproxy:latest
```

## Security Notes

1. **Never expose the statistics port (8888) to the internet** - it should only be accessible locally
2. **Use strong, randomly generated secrets**
3. **Consider using random padding** to avoid ISP detection
4. **Keep your container updated** with the latest security patches

## Troubleshooting

### Container won't start
Check the logs:
```bash
docker logs mtproxy
```

### Can't connect to proxy
1. Ensure the port is accessible from the internet
2. Check firewall settings
3. Verify the secret is correct
4. Check if your ISP blocks the connection

### Performance issues
1. Increase the number of workers: `-e WORKERS=4`
2. Ensure adequate system resources
3. Monitor with: `docker stats mtproxy`

## Automatic Updates

The GitHub Actions workflow automatically builds new images on:
- Pushes to main/master branch
- New tags (version releases)
- Manual workflow dispatch

Images are available at: `ghcr.io/getpagespeed/mtproxy:latest` 