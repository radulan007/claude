#!/usr/bin/env bash
# Installs everything needed to create, edit, animate and render videos with
# HyperFrames, Remotion and FFmpeg. Safe to re-run.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HF_VERSION="0.8.216"

log() { printf '\n==> %s\n' "$*"; }

if command -v apt-get >/dev/null 2>&1; then
  log "System packages (FFmpeg, fonts, audio/media tools)"
  SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
  $SUDO apt-get update -qq
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -qq \
    ffmpeg imagemagick sox libsox-fmt-mp3 mediainfo unzip \
    fonts-inter fonts-dejavu fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji
  fc-cache -f >/dev/null
elif command -v brew >/dev/null 2>&1; then
  log "Homebrew packages"
  brew install ffmpeg imagemagick sox mediainfo
else
  echo "No apt-get or brew found: install ffmpeg (>= 6), imagemagick, sox and mediainfo yourself." >&2
fi

node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if [ "$node_major" -lt 22 ]; then
  echo "Node.js >= 22 is required (found: $(node -v 2>/dev/null || echo none))." >&2
  exit 1
fi

log "HyperFrames project dependencies"
(cd "$ROOT/hyperframes" && npm ci --no-audit --no-fund)

log "HyperFrames headless Chrome"
(cd "$ROOT/hyperframes" && npx --yes "hyperframes@$HF_VERSION" browser ensure)

log "Remotion project dependencies"
(cd "$ROOT/remotion" && npm ci --no-audit --no-fund)

log "Remotion headless Chrome"
# remotion.config.ts reuses HyperFrames' or Playwright's Chrome when present; otherwise
# let Remotion download its own. A failed download is not fatal if one was found.
(cd "$ROOT/remotion" && npx remotion browser ensure) || \
  echo "Remotion's own Chrome download failed; renders will use the browser found by remotion.config.ts."

log "Setup complete. Run scripts/verify.sh to render test videos."
