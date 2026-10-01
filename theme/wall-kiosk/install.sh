#!/bin/bash
# Install the wall-kiosk live-background wiring: systemd user units for the
# capture timer and the omarchy hooks that start/stop it on theme switches.
#
# Run AFTER `omarchy theme install <this-repo>` has cloned the theme:
#   omarchy theme install <repo-url>
#   ~/.config/omarchy/themes/wall-kiosk/install.sh
#
# Idempotent: safe to re-run after edits to the units/hooks in this repo.
set -euo pipefail

THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_NAME="$(basename "$THEME_DIR")"

if [[ ! -x "$THEME_DIR/bin/wall-kiosk-refresh.sh" ]]; then
  echo "install.sh: '$THEME_DIR' doesn't look like the wall-kiosk theme (missing bin/wall-kiosk-refresh.sh). Aborting." >&2
  exit 1
fi

mkdir -p "$HOME/.config/systemd/user"
mkdir -p "$HOME/.config/omarchy/hooks/theme-set.d"
mkdir -p "$HOME/.config/omarchy/hooks/post-boot.d"

# systemd user units (capture service + refresh timer)
install -m 0644 "$THEME_DIR/systemd/wall-kiosk-capture.service" "$HOME/.config/systemd/user/"
install -m 0644 "$THEME_DIR/systemd/wall-kiosk-capture.timer"   "$HOME/.config/systemd/user/"
echo "installed systemd units:"
echo "  $HOME/.config/systemd/user/wall-kiosk-capture.service"
echo "  $HOME/.config/systemd/user/wall-kiosk-capture.timer"

# omarchy hooks: keep the timer running only while wall-kiosk is active,
# and restore it on the next login if it was already the active theme.
install -m 0755 "$THEME_DIR/hooks/theme-set.d/wall-kiosk-capture-toggle" "$HOME/.config/omarchy/hooks/theme-set.d/"
install -m 0755 "$THEME_DIR/hooks/post-boot.d/wall-kiosk-capture-resume" "$HOME/.config/omarchy/hooks/post-boot.d/"
echo "installed hooks:"
echo "  $HOME/.config/omarchy/hooks/theme-set.d/wall-kiosk-capture-toggle"
echo "  $HOME/.config/omarchy/hooks/post-boot.d/wall-kiosk-capture-resume"

systemctl --user daemon-reload
echo "reloaded user systemd"

# Start the timer only if wall-kiosk is already the active theme; otherwise
# the theme-set hook will enable it when the user switches to wall-kiosk.
current_theme=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || echo "")
if [[ $current_theme == "$THEME_NAME" ]]; then
  systemctl --user enable --now wall-kiosk-capture.timer >/dev/null 2>&1 || \
    echo "warning: could not enable the capture timer (no user systemd session?)" >&2
  echo "started wall-kiosk-capture.timer (active theme is '$current_theme')"
  echo "first capture will land in ~5s"
else
  echo "active theme is '$current_theme' (not '$THEME_NAME'); timer left stopped."
  echo "Switch with 'omarchy theme set $THEME_NAME' and the timer will start."
fi

echo
echo "Done. Prerequisites: chromium and python-websocket-client must be installed."
echo "To point the live wallpaper at a different URL, edit $THEME_DIR/wall-kiosk.env"
