#!/usr/bin/env bash
set -euo pipefail

# Webhook URL（rootのみ読める想定）
# shellcheck disable=SC1091
source /etc/slack/webhook.env

HOST="$(hostname)"
BOOT_ID="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo unknown)"
KERNEL="$(uname -r)"
NOW="$(date -Iseconds)"

IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
IP="${IP:-unknown}"

# ネットワーク待ち（最大60秒）
for _ in {1..20}; do
  curl -sS --max-time 3 https://slack.com >/dev/null 2>&1 && break
  sleep 3
done

# 時刻同期待ち（最大60秒）
for _ in {1..20}; do
  timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -qi '^yes$' && break
  sleep 3
done

BOOT_TIME="$(uptime -s 2>/dev/null || date -Iseconds)"
UPTIME_SEC="$(cut -d. -f1 /proc/uptime 2>/dev/null || echo unknown)"

# wtmp（事実）
PREV_WTMP="$(last -x -n 6 reboot shutdown 2>/dev/null | head -n 6 || true)"

# 前回ブートログから推定（推定 + 根拠）
J_PREV_AVAILABLE="yes"
if ! journalctl -b -1 -n 1 --no-pager >/dev/null 2>&1; then
  J_PREV_AVAILABLE="no"
fi

PREV_HINT="unknown"
PREV_EVIDENCE="(no evidence)"

if [ "$J_PREV_AVAILABLE" = "yes" ]; then
  SIG="$(journalctl -b -1 --no-pager -n 600 2>/dev/null | \
    grep -Ei 'kernel panic|watchdog|soft lockup|hard lockup|oops|reboot: Restarting system|Restarting system|Reached target Reboot|Reached target Power-Off|Power down|systemd-shutdown' | \
    tail -n 12 || true)"

  if echo "$SIG" | grep -Eqi 'kernel panic|oops|soft lockup|hard lockup'; then
    PREV_HINT="crash (kernel/panic/oops suspected)"
    PREV_EVIDENCE="$SIG"
  elif echo "$SIG" | grep -Eqi 'watchdog'; then
    PREV_HINT="watchdog reset suspected"
    PREV_EVIDENCE="$SIG"
  elif echo "$SIG" | grep -Eqi 'Reached target Reboot|reboot: Restarting system|Restarting system'; then
    PREV_HINT="graceful reboot"
    PREV_EVIDENCE="$SIG"
  elif echo "$SIG" | grep -Eqi 'Reached target Power-Off|Power down|systemd-shutdown'; then
    PREV_HINT="graceful shutdown"
    PREV_EVIDENCE="$SIG"
  else
    PREV_HINT="unclear (could be power loss if no shutdown logs exist)"
    PREV_EVIDENCE="(no matching signature in last 600 lines of prev boot)"
  fi
else
  PREV_HINT="prev-boot journal unavailable (enable persistent journal)"
  PREV_EVIDENCE="(journalctl -b -1 not accessible)"
fi

MSG=":arrows_counterclockwise: VirtualBox guest boot detected
*host:* ${HOST}
*ip:* ${IP}
*now:* ${NOW}
*boot_time:* ${BOOT_TIME}
*uptime_sec:* ${UPTIME_SEC}
*kernel:* ${KERNEL}
*boot_id:* ${BOOT_ID}

*prev_boot_inference:* ${PREV_HINT}
*prev_boot_evidence (log signature):*
\`\`\`
${PREV_EVIDENCE}
\`\`\`

*reboot/shutdown history (wtmp):*
\`\`\`
${PREV_WTMP}
\`\`\`"

export MSG
python3 - <<'PY' | curl -fsS -X POST -H 'Content-type: application/json' --data-binary @- "$SLACK_WEBHOOK_URL" >/dev/null
import json, os
print(json.dumps({"text": os.environ["MSG"]}))
PY
