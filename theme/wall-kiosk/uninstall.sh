#!/bin/bash
# Remove the wall-kiosk live-background wiring installed by install.sh:
# the capture timer/service and the theme/hook wiring. The theme directory
# itself is left in place -- remove it with:
#   rm -rf ~/.config/omarchy/themes/wall-kiosk
# (or `omarchy theme set <other>` first to avoid switching away from a
# wallpaper that no longer refreshes).
set -euo pipefail

systemctl --user disable --now wall-kiosk-capture.timer >/dev/null 2>&1 || true
echo "stopped and disabled wall-kiosk-capture.timer"

rm -f "$HOME/.config/systemd/user/wall-kiosk-capture.service"
rm -f "$HOME/.config/systemd/user/wall-kiosk-capture.timer"
echo "removed systemd units"

rm -f "$HOME/.config/omarchy/hooks/theme-set.d/wall-kiosk-capture-toggle"
rm -f "$HOME/.config/omarchy/hooks/post-boot.d/wall-kiosk-capture-resume"
echo "removed hooks"

systemctl --user daemon-reload
echo "reloaded user systemd"
echo "Uninstalled. The last captured background image is still on your wallpaper."
