#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: run as root (use sudo)" >&2
  exit 1
fi

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
FILES_DIR="${REPO_DIR}/files"

echo "[1/6] Install script and unit files"
install -m 0755 "${FILES_DIR}/notify-slack-boot.sh" /usr/local/bin/notify-slack-boot.sh
install -m 0644 "${FILES_DIR}/slack-boot-notify.service" /etc/systemd/system/slack-boot-notify.service

echo "[2/6] Setup webhook env (if missing)"
mkdir -p /etc/slack
chmod 700 /etc/slack

if [ ! -f /etc/slack/webhook.env ]; then
  cat > /etc/slack/webhook.env <<'EOW'
# Put your Slack Incoming Webhook URL here:
# SLACK_WEBHOOK_URL="https://hooks.slack.com/services/XXX/YYY/ZZZ"
SLACK_WEBHOOK_URL=""
EOW
  chmod 600 /etc/slack/webhook.env
  chown root:root /etc/slack/webhook.env
  echo "Created /etc/slack/webhook.env (please edit and set SLACK_WEBHOOK_URL)"
else
  chmod 600 /etc/slack/webhook.env
  chown root:root /etc/slack/webhook.env
fi

echo "[3/6] Enable persistent journal (recommended)"
mkdir -p /var/log/journal
if ! grep -qE '^\s*Storage\s*=\s*persistent' /etc/systemd/journald.conf 2>/dev/null; then
  printf "\n[Journal]\nStorage=persistent\n" >> /etc/systemd/journald.conf
fi
systemctl restart systemd-journald

echo "[4/6] Reload systemd"
systemctl daemon-reload

echo "[5/6] Enable service"
systemctl enable slack-boot-notify.service >/dev/null

echo "[6/6] Run once (will fail if webhook URL is empty)"
set +e
systemctl start slack-boot-notify.service
RC=$?
set -e

if grep -qE '^SLACK_WEBHOOK_URL="\s*"$|^SLACK_WEBHOOK_URL=\s*$' /etc/slack/webhook.env; then
  echo "NOTE: Slack Webhook URL is empty. Edit /etc/slack/webhook.env and re-run:"
  echo "  sudo systemctl restart slack-boot-notify.service"
else
  if [ $RC -eq 0 ]; then
    echo "OK: service executed"
  else
    echo "WARN: service returned non-zero. Check:"
    echo "  journalctl -u slack-boot-notify.service -n 100 --no-pager"
    exit $RC
  fi
fi
