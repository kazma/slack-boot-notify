# slack-boot-notify

Linuxホスト（VirtualBoxゲスト等）の起動/再起動時に Slack へ通知します。

通知内容は以下を含みます。

- host / ip / now / boot_time / uptime_sec / kernel / boot_id
- prev_boot_inference（前回ブートの状況推定）
- prev_boot_evidence（推定根拠のログ断片）
- reboot/shutdown history（wtmp の抜粋）

## 要件

- systemd / journald
- curl / python3
- Slack Incoming Webhook URL
- `last` コマンド（wtmp が読める環境）

## インストール

    git clone <your-repo-url>
    cd slack-boot-notify
    sudo ./install.sh

Webhook URL を設定（漏洩厳禁、rootのみ参照）:

    sudo vi /etc/slack/webhook.env
    # SLACK_WEBHOOK_URL="https://hooks.slack.com/services/XXX/YYY/ZZZ"
    sudo chmod 600 /etc/slack/webhook.env
    sudo chown root:root /etc/slack/webhook.env

動作確認（手動実行）:

    sudo systemctl restart slack-boot-notify.service
    sudo systemctl status slack-boot-notify.service --no-pager

## ログ

    journalctl -u slack-boot-notify.service -n 100 --no-pager

## アンインストール

    sudo ./uninstall.sh

## 補足

- `prev_boot_*` の精度を上げるため、インストール時に journald を永続化（`/var/log/journal`）します。
- ネットワーク確立や時刻同期が遅い環境向けに、送信前にリトライ/待機を入れています。

