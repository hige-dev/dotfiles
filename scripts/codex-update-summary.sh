#!/usr/bin/env bash
set -euo pipefail

mise="$HOME/.local/bin/mise"
summary_script="$HOME/.local/share/dotfiles/codex-update-summary.mjs"

if [[ -x "$mise" ]] && "$mise" ls --installed node 2>/dev/null | grep -Fq '__NODE_VERSION__'; then
  exec "$mise" exec "node@__NODE_VERSION__" -- node "$summary_script"
fi

if command -v node >/dev/null 2>&1 && node --version >/dev/null 2>&1; then
  exec node "$summary_script"
fi

exit 0
