#!/bin/bash
# Refresh the wall-kiosk live background: capture a fresh screenshot of the
# dashboard and hand it to Omarchy's normal wallpaper mechanism.
#
# Safety: only acts while "wall-kiosk" is actually the active theme, so a
# stray timer tick after switching themes (a small race can exist between
# `omarchy theme set <other>` and our theme-set hook stopping the timer)
# can't clobber whatever background the user just switched to.
set -euo pipefail

THEME_DIR="$HOME/.config/omarchy/themes/wall-kiosk"
BACKGROUNDS_DIR="$THEME_DIR/backgrounds"
THEME_NAME_FILE="$HOME/.local/state/omarchy/current/theme.name"
CAPTURE="$THEME_DIR/bin/wall-kiosk-capture.py"

current_theme=$(cat "$THEME_NAME_FILE" 2>/dev/null || echo "")
if [[ $current_theme != "wall-kiosk" ]]; then
  echo "wall-kiosk-refresh: theme is '$current_theme', not wall-kiosk; skipping capture"
  exit 0
fi

mkdir -p "$BACKGROUNDS_DIR"

# Alternate between two filenames each cycle. Omarchy's background renderer
# compares the *path string* of the new background to the current one to
# decide whether to run its reveal transition -- reusing a single filename
# would look like "no change" and never refresh the on-screen image.
CURRENT_LINK="$HOME/.local/state/omarchy/current/background"
if [[ -e $CURRENT_LINK && $(readlink -f "$CURRENT_LINK" 2>/dev/null) == "$BACKGROUNDS_DIR/live-a.png" ]]; then
  TARGET="$BACKGROUNDS_DIR/live-b.png"
else
  TARGET="$BACKGROUNDS_DIR/live-a.png"
fi

python3 "$CAPTURE" "$TARGET"

# Re-check we're still on wall-kiosk before switching the live background --
# capture takes several seconds and the theme may have changed meanwhile.
current_theme=$(cat "$THEME_NAME_FILE" 2>/dev/null || echo "")
if [[ $current_theme != "wall-kiosk" ]]; then
  echo "wall-kiosk-refresh: theme changed during capture; not applying"
  exit 0
fi

omarchy-theme-bg-set "$TARGET"
