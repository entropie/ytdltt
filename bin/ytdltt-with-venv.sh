#!/usr/bin/env bash
set -e

VENV="${YT_DLP_VENV_DIR:-$HOME/.yt-dlp-venv}"

python3 -m venv "$VENV"
source "$VENV/bin/activate"

"$VENV/bin/pip" install -U pip yt-dlp

export PATH="$VENV/bin:$PATH"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec ruby "$SCRIPT_DIR/ytdltt" "$@"
