#!/usr/bin/env bash
# macOS の標準 Bash 3.2 でも動く構文を使用する
set -euo pipefail
dotfiles_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$dotfiles_dir/versions.sh"
configs_only=false
dry_run=false
target_home="$HOME"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --configs-only) configs_only=true ;;
    --dry-run) dry_run=true ;;
    --target-home)
      [[ $# -ge 2 && -n "$2" ]] || { printf '%s\n' '配置先を指定してください。' >&2; exit 1; }
      target_home="$2"; shift ;;
    -h|--help)
      printf '%s\n' '使い方: bash setup.sh [--configs-only] [--dry-run] [--target-home 配置先]'
      exit 0 ;;
    *) printf '不明な引数です: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done
[[ "$target_home" == /* ]] || { printf '%s\n' '配置先は絶対パスで指定してください。' >&2; exit 1; }
if ! $configs_only && [[ "$target_home" != "$HOME" ]]; then
  printf '%s\n' '--target-home は --configs-only と組み合わせて使用してください。' >&2
  exit 1
fi
# 配置先の衝突は、依存関係導入やファイル配置を始める前に確認する
for relative_path in .tmux.conf .zshrc .p10k.zsh .codex/AGENTS.md .codex/config.toml .local/bin/agent-notify.sh .local/bin/tmux-copy.sh; do
  if [[ -d "$target_home/$relative_path" && ! -L "$target_home/$relative_path" ]]; then
    printf '配置先がディレクトリです: %s\n' "$target_home/$relative_path" >&2
    exit 1
  fi
done
backup_dir="$target_home/.local/state/dotfiles/backups/$(date +%Y%m%d-%H%M%S)-$$"
staging_dir=""
cleanup() { [[ -z "$staging_dir" ]] || rm -rf -- "$staging_dir"; }
trap cleanup EXIT

place() {
  local source_file="$1" relative_path="$2" mode="$3" destination
  destination="$target_home/$relative_path"
  if $dry_run; then
    printf '配置予定: %s\n' "$destination"
    return
  fi
  # リンク先がディレクトリでも、リンク自体は退避できる
  if [[ -d "$destination" && ! -L "$destination" ]]; then
    printf '配置先がディレクトリです: %s\n' "$destination" >&2
    return 1
  fi
  if [[ -f "$destination" && ! -L "$destination" ]] && cmp -s "$source_file" "$destination"; then
    chmod "$mode" "$destination"
    printf '変更なし: %s\n' "$destination"
    return
  fi
  mkdir -p -- "$(dirname -- "$destination")"
  if [[ -e "$destination" || -L "$destination" ]]; then
    mkdir -p -- "$(dirname -- "$backup_dir/$relative_path")"
    mv -- "$destination" "$backup_dir/$relative_path"
    printf '退避: %s\n' "$backup_dir/$relative_path"
  fi
  install -m "$mode" "$source_file" "$destination"
  printf '配置: %s\n' "$destination"
}

install_dependencies() {
  case "$(uname -s)" in
    Darwin)
      if ! command -v brew >/dev/null 2>&1; then
        if [[ -x /opt/homebrew/bin/brew ]]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x /usr/local/bin/brew ]]; then
          eval "$(/usr/local/bin/brew shellenv)"
        else
          curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$staging_dir/homebrew-install.sh"
          /bin/bash "$staging_dir/homebrew-install.sh"
          if [[ -x /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
          else
            eval "$(/usr/local/bin/brew shellenv)"
          fi
        fi
      fi
      brew install zsh tmux git curl jq
      ;;
    Linux)
      [[ -f /etc/debian_version ]] || { printf '%s\n' 'Linux の自動導入は Ubuntu / Debian が対象です。' >&2; return 1; }
      local privilege=()
      [[ "$(id -u)" == 0 ]] || privilege=(sudo)
      "${privilege[@]}" apt-get update
      "${privilege[@]}" apt-get install -y zsh tmux git curl jq ca-certificates libnotify-bin
      ;;
    *) printf '%s\n' '自動導入の対象は macOS / Ubuntu / Debian / WSL です。' >&2; return 1 ;;
  esac
  local relative_path url revision destination current
  while read -r relative_path url revision; do
    [[ -n "$relative_path" ]] || continue
    destination="$target_home/$relative_path"
    if [[ -e "$destination" ]]; then
      current="$(git -C "$destination" rev-parse HEAD)"
      [[ "$current" == "$revision" ]] || { printf '既存の版が異なります。退避して再実行してください: %s\n' "$destination" >&2; return 1; }
    else
      mkdir -p -- "$(dirname -- "$destination")"
      git clone --no-checkout "$url" "$destination"
      git -C "$destination" checkout --detach "$revision"
    fi
  done < "$dotfiles_dir/repositories.txt"
  local mise="$target_home/.local/bin/mise"
  current=""
  [[ ! -x "$mise" ]] || current="$("$mise" --version | cut -d ' ' -f 1)"
  if [[ "$current" != "$MISE_VERSION_PIN" ]]; then
    mkdir -p -- "$(dirname -- "$mise")"
    curl -fsSL https://mise.run -o "$staging_dir/mise-install.sh"
    MISE_VERSION="v$MISE_VERSION_PIN" MISE_INSTALL_PATH="$mise" sh "$staging_dir/mise-install.sh"
  fi
  "$mise" install "node@$NODE_VERSION_PIN"
  "$mise" exec "node@$NODE_VERSION_PIN" -- npm install --global --prefix "$target_home/.local/share/dotfiles/npm" "@openai/codex@$CODEX_VERSION_PIN"
}

if ! $dry_run; then
  staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles.XXXXXX")"
  if ! $configs_only; then install_dependencies; fi
fi
place "$dotfiles_dir/tmux/tmux.conf" .tmux.conf 644
place "$dotfiles_dir/zsh/zshrc" .zshrc 644
place "$dotfiles_dir/zsh/p10k.zsh" .p10k.zsh 644
place "$dotfiles_dir/codex/AGENTS.md" .codex/AGENTS.md 644
place "$dotfiles_dir/scripts/agent-notify.sh" .local/bin/agent-notify.sh 755
place "$dotfiles_dir/scripts/tmux-copy.sh" .local/bin/tmux-copy.sh 755
if $dry_run; then
  place "$dotfiles_dir/codex/config.toml" .codex/config.toml 600
else
  cat "$dotfiles_dir/codex/config.toml" > "$staging_dir/config.toml"
  if [[ -f "$dotfiles_dir/codex/local.toml" ]]; then
    printf '\n' >> "$staging_dir/config.toml"
    cat "$dotfiles_dir/codex/local.toml" >> "$staging_dir/config.toml"
  fi
  place "$staging_dir/config.toml" .codex/config.toml 600
fi
if [[ -f "$dotfiles_dir/zsh/local.zsh" ]]; then
  place "$dotfiles_dir/zsh/local.zsh" .zshrc.local 600
fi
if ! $configs_only; then
  if $dry_run; then
    printf '%s\n' '導入予定: OS の基本ツール、固定版の zsh 拡張・mise・Node.js・Codex・interview-dev-loop'
  else
    sed "s/__NODE_VERSION__/$NODE_VERSION_PIN/g" "$dotfiles_dir/scripts/codex.sh" > "$staging_dir/codex"
    place "$staging_dir/codex" .local/bin/codex 755
    "$target_home/.local/bin/codex" plugin marketplace add "$MARKETPLACE_SOURCE" --ref "$MARKETPLACE_REVISION"
    "$target_home/.local/bin/codex" plugin add "$PLUGIN_NAME"
  fi
fi
printf '%s\n' '完了しました。新しい zsh を開いてください。Codex のログインとフックの信頼確認は端末ごとに行います。'
