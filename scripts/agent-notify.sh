#!/usr/bin/env bash
# JSON の読み取りだけ jq に任せ、OS 標準の通知を使用する
set -euo pipefail
test_mode=false
provider=codex
while [[ $# -gt 0 ]]; do
  case "$1" in
    --test) test_mode=true ;;
    --provider)
      [[ $# -ge 2 ]] || { printf '%s\n' '通知元を指定してください。' >&2; exit 1; }
      provider="$2"; shift ;;
    *) printf '不明な引数です: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done
[[ "$provider" == codex ]] || { printf '%s\n' '通知元は codex を指定してください。' >&2; exit 1; }
if $test_mode; then
  title='通知テスト'
  message='デスクトップ通知が表示されます'
else
  command -v jq >/dev/null || { printf '%s\n' '通知には jq が必要です。' >&2; exit 1; }
  payload="$(cat)"
  jq -e 'type == "object"' >/dev/null <<< "$payload" || { printf '%s\n' '通知データは JSON オブジェクトである必要があります。' >&2; exit 1; }
  tool="$(jq -r '(.tool_name // "ツール") | tostring | gsub("[\\r\\n\\t]"; " ") | .[0:40]' <<< "$payload")"
  project="$(jq -r '(.cwd // "") | tostring | gsub("\\\\"; "/") | split("/") | map(select(length > 0)) | last // ""' <<< "$payload")"
  title='Codex が確認待ちです'
  message="$tool の実行許可が必要です"
  [[ -z "$project" ]] || message="$message · $project"
fi
case "$(uname -s)" in
  Darwin)
    osascript - "$title" "$message" <<'APPLESCRIPT'
on run argv
  display notification (item 2 of argv) with title (item 1 of argv)
end run
APPLESCRIPT
    ;;
  Linux)
    if [[ -n "${WSL_DISTRO_NAME:-}" ]] || uname -r | grep -qi microsoft; then
      command -v powershell.exe >/dev/null || { printf '%s\n' 'Windows の PowerShell が見つかりません。' >&2; exit 1; }
      # 引用符や改行のある文字列も安全に PowerShell に渡す
      title_encoded="$(printf '%s' "$title" | base64 | tr -d '\r\n')"
      message_encoded="$(printf '%s' "$message" | base64 | tr -d '\r\n')"
      script="$(cat <<POWERSHELL
\$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
\$notification = New-Object System.Windows.Forms.NotifyIcon
\$notification.Icon = [System.Drawing.SystemIcons]::Information
\$notification.BalloonTipTitle = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$title_encoded'))
\$notification.BalloonTipText = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$message_encoded'))
\$notification.Visible = \$true
\$notification.ShowBalloonTip(5000)
Start-Sleep -Seconds 5
\$notification.Dispose()
POWERSHELL
)"
      encoded="$(printf '%s' "$script" | iconv -f UTF-8 -t UTF-16LE | base64 | tr -d '\r\n')"
      powershell.exe -NoProfile -NonInteractive -STA -WindowStyle Hidden -EncodedCommand "$encoded" </dev/null
    else
      notify-send "$title" "$message"
    fi
    ;;
  *) printf '%s\n' '通知に対応していない OS です。' >&2; exit 1 ;;
esac
