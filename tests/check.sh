#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-check.XXXXXX")"
socket="$test_dir/tmux.sock"
cleanup() {
  tmux -S "$socket" kill-server 2>/dev/null || true
  rm -rf -- "$test_dir"
}
trap cleanup EXIT
for file in "$root/setup.sh" "$root/versions.sh" "$root"/scripts/*.sh "$root/tests/check.sh"; do
  bash -n "$file"
done
zsh -n "$root/zsh/zshrc"
zsh -n "$root/zsh/p10k.zsh"
home_dir="$test_dir/空白 のあるホーム"
mkdir -p "$home_dir/.codex"
printf '%s\n' '元の設定' > "$home_dir/.tmux.conf"
printf '%s\n' '認証情報は変更しない' > "$home_dir/.codex/auth.json"
printf '%s\n' '元のリンク先' > "$test_dir/original"
ln -s "$test_dir/original" "$home_dir/.zshrc"
bash "$root/setup.sh" --configs-only --target-home "$home_dir" --dry-run >/dev/null
[[ "$(cat "$home_dir/.tmux.conf")" == '元の設定' ]]
bash "$root/setup.sh" --configs-only --target-home "$home_dir" >/dev/null
cmp "$root/tmux/tmux.conf" "$home_dir/.tmux.conf"
cmp "$root/codex/config.toml" "$home_dir/.codex/config.toml"
[[ "$(cat "$home_dir/.codex/auth.json")" == '認証情報は変更しない' ]]
[[ "$(cat "$test_dir/original")" == '元のリンク先' ]]
backups=("$home_dir/.local/state/dotfiles/backups/"*)
[[ ${#backups[@]} == 1 ]]
[[ -L "${backups[0]}/.zshrc" ]]
[[ "$(cat "${backups[0]}/.tmux.conf")" == '元の設定' ]]
bash "$root/setup.sh" --configs-only --target-home "$home_dir" >/dev/null
backups=("$home_dir/.local/state/dotfiles/backups/"*)
[[ ${#backups[@]} == 1 ]]
if bash "$root/setup.sh" --target-home "$home_dir" >/dev/null 2>&1; then
  printf '%s\n' '検証失敗: 別ホームへの依存関係導入が許可されました。' >&2
  exit 1
fi
printf '%s\n' '配置・再実行・退避・リンク先保護・認証情報保持: 成功'

# 実際の通知を送らず、macOS / Linux / WSL の OS 分岐を確認
mkdir "$test_dir/bin"
cat > "$test_dir/bin/uname" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == -s ]]; then printf '%s\n' "$TEST_OS"; else printf '%s\n' '通常のカーネル'; fi
STUB
cat > "$test_dir/bin/osascript" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$TEST_CAPTURE"
cat >/dev/null
STUB
cp "$test_dir/bin/osascript" "$test_dir/bin/notify-send"
cp "$test_dir/bin/osascript" "$test_dir/bin/powershell.exe"
cat > "$test_dir/bin/pbcopy" <<'STUB'
#!/usr/bin/env bash
cat > "$TEST_CAPTURE"
STUB
chmod +x "$test_dir/bin/"*
payload='{"tool_name":"検証ツール","cwd":"/作業/日本語のプロジェクト"}'
printf '%s' "$payload" | TEST_OS=Darwin TEST_CAPTURE="$test_dir/mac" PATH="$test_dir/bin:$PATH" bash "$root/scripts/agent-notify.sh"
grep -q '日本語のプロジェクト' "$test_dir/mac"
printf '%s' "$payload" | TEST_OS=Linux WSL_DISTRO_NAME='' TEST_CAPTURE="$test_dir/linux" PATH="$test_dir/bin:$PATH" bash "$root/scripts/agent-notify.sh"
grep -q '検証ツール' "$test_dir/linux"
printf '%s' "$payload" | TEST_OS=Linux WSL_DISTRO_NAME=Ubuntu TEST_CAPTURE="$test_dir/wsl" PATH="$test_dir/bin:$PATH" bash "$root/scripts/agent-notify.sh"
grep -q -- '-EncodedCommand' "$test_dir/wsl"
if printf '%s' '[]' | TEST_OS=Darwin PATH="$test_dir/bin:$PATH" bash "$root/scripts/agent-notify.sh" >/dev/null 2>&1; then
  printf '%s\n' '検証失敗: 無効な通知データが受理されました。' >&2
  exit 1
fi
printf '%s' 'コピーする日本語' | TEST_OS=Darwin TEST_CAPTURE="$test_dir/clipboard" PATH="$test_dir/bin:$PATH" bash "$root/scripts/tmux-copy.sh"
[[ "$(cat "$test_dir/clipboard")" == 'コピーする日本語' ]]
cp "$test_dir/bin/pbcopy" "$test_dir/bin/clip.exe"
printf '%s' 'WSL の日本語コピー' | TEST_OS=Linux TEST_CAPTURE="$test_dir/clipboard-wsl" PATH="$test_dir/bin:$PATH" bash "$root/scripts/tmux-copy.sh"
[[ "$(iconv -f UTF-16LE -t UTF-8 "$test_dir/clipboard-wsl")" == 'WSL の日本語コピー' ]]
printf '%s\n' 'macOS / Linux / WSL の通知分岐・JSON 検証・macOS / WSL コピー: 成功'

tmux -S "$socket" -f "$root/tmux/tmux.conf" new-session -d -s check
tmux -S "$socket" source-file "$root/tmux/tmux.conf"
[[ "$(tmux -S "$socket" show-options -gwv window-style)" == 'fg=default,bg=#333333' ]]
[[ "$(tmux -S "$socket" show-options -gwv window-active-style)" == 'fg=default,bg=terminal' ]]
tmux -S "$socket" kill-server
printf '%s\n' 'tmux の起動・再読み込み・背景設定: 成功'
