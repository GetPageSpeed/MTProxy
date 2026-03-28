# MTProxy bởi GetPageSpeed

**[English](README.md)** | **[Русский](README.ru.md)** | **[فارسی](README.fa.md)**

Proxy MT-Proto cho Telegram. **[Kênh Telegram](https://t.me/mtproxy_dev)** để theo dõi cập nhật.

**Đây là một fork của MTProxy với các cải tiến và sửa lỗi mà repository gốc không merge do đã ngừng phát triển.
Mục tiêu chính — vận hành ổn định MTProxy trong môi trường production.**

> [!IMPORTANT]
> **Dự án được duy trì bởi [một nhà phát triển duy nhất](https://github.com/dvershinin) trong thời gian rảnh.**
> Repository gốc [TelegramMessenger/MTProxy](https://github.com/TelegramMessenger/MTProxy) đã bị bỏ rơi.
> Phát triển tiếp phụ thuộc vào sự hỗ trợ của cộng đồng.
>
> | Kênh | |
> |-------|---------|
> | GitHub Sponsors | **[Tài trợ](https://github.com/sponsors/dvershinin)** |
> | Tribute | **[Donate qua Telegram](https://t.me/tribute/app?startapp=dHGI)** (thẻ, toàn cầu) |
> | TON | `UQBOGq_b3eL63Qfkj6ykoBibK3zGJDQzLK91v2q-UCY7BPeb` (qua @wallet trên Telegram) |
> | USDT (TRC-20) | `TNVSj1QjZ5jqdaeshe7VCpXWo2S1n936Hj` |
> | BTC | `bc1qvxxldmanwggula7992uun5a2qxm65ej9h0unj7` |
> | Thương mại | **[Gói RPM từ GetPageSpeed](https://www.getpagespeed.com/server-setup/mtproxy)** |

## So sánh với các giải pháp khác

Fork này là phiên bản duy nhất được bảo trì tích cực của [TelegramMessenger/MTProxy](https://github.com/TelegramMessenger/MTProxy).

| Tính năng | [Gốc](https://github.com/TelegramMessenger/MTProxy) | **Fork này** | [mtg](https://github.com/9seconds/mtg) | [telemt](https://github.com/telemt/telemt) |
|---------|:---:|:---:|:---:|:---:|
| **Ngôn ngữ** | C | C | Go | Rust |
| ***Giao thức*** | | | | |
| Fake-TLS (chế độ EE) | Có | Có | Có | Có |
| Kết nối trực tiếp DC | Không | Có | Có | Có |
| Tag quảng cáo | Có | Có | Không | Có |
| Nhiều secret | Có | Có (tối đa 16, có nhãn) | Không | Có |
| Chống replay attack | Yếu | Có | Có | Một phần |
| HMAC thời gian hằng | Không | Có | — | Có |
| ***Chống phân tích DPI*** | | | | |
| TLS backend tùy chỉnh | Có | Có | Không | Có |
| Dynamic Record Sizing (DRS) | Không | Có | Có | Không |
| Giả lập traffic (DRS + timing) | Không | Có | Có | Không |
| SOCKS5 upstream proxy | Không | Không | Có | Có |
| ***Kiểm soát truy cập*** | | | | |
| IP blocklist / allowlist | Không | Có | Có | Không |
| Giới hạn IP theo user | Không | Không | Không | Có |
| Proxy Protocol v1/v2 | Không | Không | Có | Có |
| ***Triển khai*** | | | | |
| Dung lượng Docker | ~57 MB | ~8 MB | ~3.5 MB | ~5 MB |
| ARM64 / Apple Silicon | Không | Có | Có | Có |
| IPv6 | Có | Có | Có | Có |
| Multi-worker | Có | Có | — | — |
| Binary tĩnh | Không | Có | Có | Có |
| ***Giám sát*** | | | | |
| Prometheus metrics | Không | Có | Có | Có |
| HTTP stats | Có | Có | — | Có |
| Health check | Không | Có | Có | Có |
| ***Kiểm thử*** | | | | |
| Fuzz testing (CI) | Không | Có | Không | Một phần |
| E2E test (Telethon) | Không | Có | Không | Không |
| Phân tích tĩnh (CI) | Không | Có | Có | — |

## Cài đặt

### Binary tĩnh (mọi Linux)

```bash
# Tải về (amd64 hoặc arm64)
curl -Lo mtproto-proxy https://github.com/GetPageSpeed/MTProxy/releases/latest/download/mtproto-proxy-linux-amd64
chmod +x mtproto-proxy

# Tạo secret
SECRET=$(head -c 16 /dev/urandom | xxd -ps)

# Chạy ở chế độ direct (đơn giản nhất — không cần file cấu hình)
./mtproto-proxy -S "$SECRET" -H 443 --direct -p 8888 --aes-pwd /dev/null
```

### Docker (khởi động nhanh)

```bash
docker run -d \
  --name mtproxy \
  -p 443:443 \
  -p 8888:8888 \
  --restart unless-stopped \
  ghcr.io/getpagespeed/mtproxy:latest
```

Container tự động:
- Tải cấu hình từ Telegram
- Tạo secret ngẫu nhiên (nếu chưa cung cấp)
- Khởi động proxy trên cổng 443

Link kết nối trong log:

```bash
docker logs mtproxy
```

### Docker với Fake-TLS (chế độ EE)

```bash
docker run -d \
  --name mtproxy \
  -p 443:443 \
  -p 8888:8888 \
  -e EE_DOMAIN=www.google.com \
  --restart unless-stopped \
  ghcr.io/getpagespeed/mtproxy:latest
```

### Docker chế độ Direct

```bash
docker run -d \
  --name mtproxy \
  -p 443:443 \
  -p 8888:8888 \
  -e DIRECT_MODE=true \
  --restart unless-stopped \
  ghcr.io/getpagespeed/mtproxy:latest
```

Chế độ direct kết nối trực tiếp tới server Telegram, bỏ qua ME relay. Không cần `proxy-multi.conf`. Không tương thích với tag quảng cáo (`PROXY_TAG`).

## Chế độ truyền tải

### Chế độ DD (random padding)

Thêm dữ liệu ngẫu nhiên vào gói tin để chống phân tích kích thước gói.

**Secret client:** thêm tiền tố `dd` vào secret.

### Chế độ EE (Fake-TLS)

Traffic trông giống kết nối TLS 1.3 tiêu chuẩn.

**Secret client:** `ee` + secret_server + hex_domain

```bash
SECRET="cafe1234567890abcdef1234567890ab"
DOMAIN="www.google.com"
echo -n "ee${SECRET}" && echo -n $DOMAIN | xxd -plain
```

### Chế độ EE với TLS backend tùy chỉnh

Chạy nginx với chứng chỉ thật phía sau MTProxy. Kết nối không hợp lệ được chuyển tiếp tới nginx — server không thể phân biệt với website thông thường.

**DRS (Dynamic Record Sizing):** Bản ghi TLS tự động thay đổi kích thước, mô phỏng hành vi của server HTTPS thực. Không cần cấu hình.

## Biến môi trường Docker

| Biến | Mặc định | Mô tả |
|------------|:---:|-----------|
| `SECRET` | tự động | Secret proxy — 32 ký tự hex, phân tách bằng dấu phẩy |
| `PORT` | 443 | Cổng kết nối client |
| `STATS_PORT` | 8888 | Cổng thống kê |
| `WORKERS` | 1 | Số lượng worker |
| `PROXY_TAG` | — | Tag từ @MTProxybot |
| `DIRECT_MODE` | false | Kết nối trực tiếp tới DC Telegram |
| `EE_DOMAIN` | — | Domain cho Fake-TLS |
| `EXTERNAL_IP` | tự động | IP công khai cho NAT |

## Giám sát

```bash
# Thống kê dạng text
curl http://localhost:8888/stats

# Prometheus metrics
curl http://localhost:8888/metrics
```

---

Tài liệu đầy đủ (build từ source, IPv6, systemd, nhãn secret, giới hạn kết nối): **[README.md](README.md)** (English)
