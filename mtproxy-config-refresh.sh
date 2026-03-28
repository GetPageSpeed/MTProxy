#!/bin/sh

# Downloads latest Telegram config file and reloads mtproxy upon success.
# Runs every 6 hours via /etc/cron.d/mtproxy-config-refresh inside the Docker image.
# Adapted from the RPM package cron job (mtproxy-rpm/mtproxy.cron).

T_CONF=/opt/mtproxy/data/proxy-multi.conf
T_CONF_DOWNLOAD=/opt/mtproxy/data/proxy-multi.conf-downloaded
PROXY_CONFIG_URL=${PROXY_CONFIG_URL:-https://core.telegram.org/getProxyConfig}

# Download latest config
curl -s --max-time 60 "$PROXY_CONFIG_URL" -o "$T_CONF_DOWNLOAD"

if [ ! -f "$T_CONF_DOWNLOAD" ]; then
  echo "Failed to download MTProxy configuration file to ${T_CONF_DOWNLOAD}!"
  exit 1
fi

if ! grep -q "proxy_for " "$T_CONF_DOWNLOAD" 2>/dev/null; then
  echo "Downloaded MTProxy configuration file ${T_CONF_DOWNLOAD} appears invalid!"
  rm -f "$T_CONF_DOWNLOAD"
  exit 1
fi

if ! diff -q "$T_CONF" "$T_CONF_DOWNLOAD" >/dev/null 2>&1; then
  /bin/cp "$T_CONF_DOWNLOAD" "$T_CONF"
  echo "[config-refresh] $(date): Config updated, sending SIGHUP to reload"
  kill -HUP 1
else
  echo "[config-refresh] $(date): Config unchanged, no reload needed"
fi

rm -f "$T_CONF_DOWNLOAD"
