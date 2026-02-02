#!/usr/bin/env bash
set -e

VENV="${YT_DLP_VENV_DIR:-$HOME/.yt-dlp-venv}"

if [ ! -x "$VENV/bin/yt-dlp" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -U pip yt-dlp
fi

"$VENV/bin/yt-dlp" --update-to master >/dev/null 2>&1 || true

export PATH="$VENV/bin:$PATH"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec ruby "$SCRIPT_DIR/ytdltt" "$@"
