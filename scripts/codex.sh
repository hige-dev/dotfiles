#!/usr/bin/env bash
set -euo pipefail
exec "$HOME/.local/bin/mise" exec node@__NODE_VERSION__ -- "$HOME/.local/share/dotfiles/npm/bin/codex" "$@"
