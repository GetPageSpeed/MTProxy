# MTProxy от GetPageSpeed

**[English](README.md)** | **[فارسی](README.fa.md)** | **[Tiếng Việt](README.vi.md)**

MT-Proto прокси-сервер для Telegram. **[Telegram-канал](https://t.me/mtproxy_dev)** с обновлениями.

**Это форк MTProxy с улучшениями и исправлениями, которые upstream-репозиторий не принял из-за прекращения разработки.
Основная цель — стабильная работа MTProxy в продакшене.**

> [!IMPORTANT]
> **Проект поддерживается [одним разработчиком](https://github.com/dvershinin) в свободное время.**
> Upstream [TelegramMessenger/MTProxy](https://github.com/TelegramMessenger/MTProxy) заброшен.
> Развитие зависит от поддержки сообщества.
>
> | Канал | |
> |-------|---------|
> | GitHub Sponsors | **[Спонсировать](https://github.com/sponsors/dvershinin)** |
> | Tribute | **[Донат через Telegram](https://t.me/tribute/app?startapp=dHGI)** (карты, весь мир) |
> | ЮMoney | **[Донат](https://yoomoney.ru/to/41001117748536)** (карты и кошельки) |
> | Boosty | **[Подписка](https://boosty.to/getpagespeed)** |
> | TON | `UQBOGq_b3eL63Qfkj6ykoBibK3zGJDQzLK91v2q-UCY7BPeb` (через @wallet в Telegram) |
> | USDT (TRC-20) | `TNVSj1QjZ5jqdaeshe7VCpXWo2S1n936Hj` |
> | BTC | `bc1qvxxldmanwggula7992uun5a2qxm65ej9h0unj7` |
> | Коммерческая поддержка | **[RPM-пакеты GetPageSpeed](https://www.getpagespeed.com/server-setup/mtproxy)** |

## Сравнение с альтернативами

Этот форк — единственная активно поддерживаемая версия [TelegramMessenger/MTProxy](https://github.com/TelegramMessenger/MTProxy).

| Функция | [Оригинал](https://github.com/TelegramMessenger/MTProxy) | **Этот форк** | [mtg](https://github.com/9seconds/mtg) | [telemt](https://github.com/telemt/telemt) |
|---------|:---:|:---:|:---:|:---:|
| **Язык** | C | C | Go | Rust |
| ***Протокол*** | | | | |
| Fake-TLS (EE-режим) | Да | Да | Да | Да |
| Прямое подключение к DC | Нет | Да | Да | Да |
| Рекламный тег | Да | Да | Нет | Да |
| Несколько секретов | Да | Да (до 16, с метками) | Нет | Да |
| Защита от replay-атак | Слабая | Да | Да | Частично |
| Constant-time HMAC | Нет | Да | — | Да |
| ***Устойчивость к DPI*** | | | | |
| TLS-бэкенд (TCP splitting) | Да | Да | Нет | Да |
| Dynamic Record Sizing (DRS) | Нет | Да | Да | Нет |
| Мимикрия трафика (DRS + тайминги) | Нет | Да | Да | Нет |
| SOCKS5 upstream | Нет | Нет | Да | Да |
| ***Контроль доступа*** | | | | |
| IP blocklist / allowlist | Нет | Да | Да | Нет |
| Лимит IP на пользователя | Нет | Нет | Нет | Да |
| Proxy Protocol v1/v2 | Нет | Нет | Да | Да |
| ***Развёртывание*** | | | | |
| Docker-образ | ~57 МБ | ~8 МБ | ~3.5 МБ | ~5 МБ |
| ARM64 / Apple Silicon | Нет | Да | Да | Да |
| IPv6 | Да | Да | Да | Да |
| Multi-worker | Да | Да | — | — |
| Статические бинарники | Нет | Да | Да | Да |
| RPM-пакеты | Нет | Да | Нет | Нет |
| ***Мониторинг*** | | | | |
| Prometheus-метрики | Нет | Да | Да | Да |
| HTTP-статистика | Да | Да | — | Да |
| Авто-обновление конфига | Нет | Да | Да | Да |
| Health checks | Нет | Да | Да | Да |
| ***Тестирование*** | | | | |
| Фаззинг (CI) | Нет | Да | Нет | Частично |
| E2E-тесты (Telethon) | Нет | Да | Нет | Нет |
| Статический анализ (CI) | Нет | Да | Да | — |

## Установка

### Быстрая установка (RPM)

Для CentOS/RHEL/AlmaLinux с предсобранными пакетами, автообновлениями и настройкой systemd:

**[Руководство по установке GetPageSpeed](https://www.getpagespeed.com/server-setup/mtproxy)**

### Статический бинарник (любой Linux)

```bash
# Скачать (amd64 или arm64)
curl -Lo mtproto-proxy https://github.com/GetPageSpeed/MTProxy/releases/latest/download/mtproto-proxy-linux-amd64
chmod +x mtproto-proxy

# Сгенерировать секрет
SECRET=$(head -c 16 /dev/urandom | xxd -ps)

# Запустить в direct-режиме (проще всего — не нужны конфиг-файлы)
./mtproto-proxy -S "$SECRET" -H 443 --direct -p 8888 --aes-pwd /dev/null
```

### Docker (быстрый старт)

```bash
docker run -d \
  --name mtproxy \
  -p 443:443 \
  -p 8888:8888 \
  --restart unless-stopped \
  ghcr.io/getpagespeed/mtproxy:latest
```

Контейнер автоматически:
- Скачивает конфигурацию от Telegram
- Генерирует случайный секрет (если не задан)
- Запускает прокси на порту 443

Ссылки для подключения — в логах:

```bash
docker logs mtproxy
```

### Docker с Fake-TLS (EE-режим)

```bash
docker run -d \
  --name mtproxy \
  -p 443:443 \
  -p 8888:8888 \
  -e EE_DOMAIN=www.google.com \
  --restart unless-stopped \
  ghcr.io/getpagespeed/mtproxy:latest
```

### Docker в direct-режиме

```bash
docker run -d \
  --name mtproxy \
  -p 443:443 \
  -p 8888:8888 \
  -e DIRECT_MODE=true \
  --restart unless-stopped \
  ghcr.io/getpagespeed/mtproxy:latest
```

Direct-режим подключается напрямую к серверам Telegram, минуя ME-релеи. Не требует `proxy-multi.conf`. Несовместим с рекламным тегом (`PROXY_TAG`).

## Транспортные режимы

### DD-режим (случайный padding)

Добавляет случайные данные к пакетам для защиты от анализа размеров.

**Секрет клиента:** добавьте префикс `dd` к секрету.

### EE-режим (Fake-TLS)

Трафик выглядит как стандартное TLS 1.3-соединение.

**Секрет клиента:** `ee` + секрет_сервера + hex_домена

```bash
SECRET="cafe1234567890abcdef1234567890ab"
DOMAIN="www.google.com"
echo -n "ee${SECRET}" && echo -n $DOMAIN | xxd -plain
```

### EE-режим с собственным TLS-бэкендом

Запустите nginx с настоящим сертификатом за MTProxy. Невалидные подключения перенаправляются на nginx — сервер неотличим от обычного веб-сайта.

**DRS (Dynamic Record Sizing):** TLS-записи автоматически варьируются по размеру, имитируя поведение реальных HTTPS-серверов. Никакой настройки не требуется.

## Переменные окружения Docker

| Переменная | По умолчанию | Описание |
|------------|:---:|-----------|
| `SECRET` | авто | Секрет(ы) прокси — 32 hex-символа, через запятую |
| `PORT` | 443 | Порт для клиентских подключений |
| `STATS_PORT` | 8888 | Порт статистики |
| `WORKERS` | 1 | Количество воркеров |
| `PROXY_TAG` | — | Тег от @MTProxybot |
| `DIRECT_MODE` | false | Прямое подключение к DC Telegram |
| `EE_DOMAIN` | — | Домен для Fake-TLS |
| `EXTERNAL_IP` | авто | Публичный IP для NAT |
| `IP_BLOCKLIST` | — | Путь к файлу с CIDR для блокировки |
| `IP_ALLOWLIST` | — | Путь к файлу с CIDR для разрешения |

## Мониторинг

```bash
# Текстовая статистика
curl http://localhost:8888/stats

# Prometheus-метрики
curl http://localhost:8888/metrics
```

Статистика доступна только из приватных сетей (127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16).

---

Полная документация (сборка из исходников, IPv6, systemd, метки секретов, лимиты подключений): **[README.md](README.md)** (English)
