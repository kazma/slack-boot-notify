#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: run as root (use sudo)" >&2
  exit 1
fi

systemctl disable --now slack-boot-notify.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/slack-boot-notify.service
rm -f /usr/local/bin/notify-slack-boot.sh

systemctl daemon-reload

echo "Removed service and script."
echo "NOTE: webhook file is kept: /etc/slack/webhook.env (remove manually if you want)"
