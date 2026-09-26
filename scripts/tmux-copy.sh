#!/usr/bin/env bash
set -euo pipefail
if [[ "$(uname -s)" == Darwin ]]; then
  exec pbcopy
fi
if command -v clip.exe >/dev/null 2>&1; then
  iconv -f UTF-8 -t UTF-16LE | clip.exe
elif command -v pbcopy >/dev/null 2>&1; then
  pbcopy
elif command -v wl-copy >/dev/null 2>&1; then
  wl-copy
elif command -v xclip >/dev/null 2>&1; then
  xclip -selection clipboard
else
  printf '%s\n' 'クリップボード用のコマンドが見つかりません。' >&2
  exit 1
fi
