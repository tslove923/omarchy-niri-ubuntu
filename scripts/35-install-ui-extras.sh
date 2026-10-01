#!/bin/bash
# 35-install-ui-extras.sh
#
# Installs the pieces added after the initial port: fonts (+shell fontconfig rule),
# the lock screen + idle auto-lock, and the extra bar widgets.
#
# Run AFTER 30-deploy-shell.sh and BEFORE 40-wire-session.sh, as your normal user.
# Safe to re-run.
#
#   ./35-install-ui-extras.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT_DIR="$HOME/omarchy-port"
STAMP="$(date +%Y%m%d-%H%M%S)"

log() { printf '\n==> %s\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. Fonts (Google Sans Flex + Material Symbols + Omarchy icon font)
#    + a fontconfig rule scoping the shell's UI font to Google Sans Flex.
# ---------------------------------------------------------------------------
log "Installing fonts"
mkdir -p "$HOME/.local/share/fonts"
for d in illogical-impulse-google-sans-flex illogical-impulse-material-symbols; do
  [[ -d $REPO_DIR/assets/fonts/$d ]] || continue
  cp -a "$REPO_DIR/assets/fonts/$d" "$HOME/.local/share/fonts/"
done
[[ -f $REPO_DIR/assets/fonts/omarchy.ttf ]] && \
  cp -a "$REPO_DIR/assets/fonts/omarchy.ttf" "$HOME/.local/share/fonts/"

# Shell UI font config: scoped to prgname=quickshell so it does NOT override
# "monospace" for other apps (see the file's header comment).
log "Installing shell fontconfig rule (~/.config/fontconfig/fonts.conf)"
mkdir -p "$HOME/.config/fontconfig"
if [[ -e $HOME/.config/fontconfig/fonts.conf ]]; then
  cp -a "$HOME/.config/fontconfig/fonts.conf" \
        "$HOME/.config/fontconfig/fonts.conf.bak-$STAMP"
fi
cp -a "$REPO_DIR/assets/fontconfig/fonts.conf" "$HOME/.config/fontconfig/fonts.conf"

fc-cache -f >/dev/null 2>&1 || true
log "Fonts installed: $(fc-list | grep -ciE 'Google Sans Flex|Material Symbols Rounded|omarchy') faces"

# ---------------------------------------------------------------------------
# 2. Lock screen + idle auto-lock
#    The ported shell's lock plugin owns an ext-session-lock surface and
#    authenticates via PAM. Upstream Omarchy drives hyprlock, which does not
#    exist on Ubuntu, so omarchy-system-lock calls the shell's IPC instead.
# ---------------------------------------------------------------------------
log "Installing lock/idle helpers"
mkdir -p "$HOME/.local/bin"
for f in omarchy-system-lock omarchy-launch-screensaver omarchy-system-wake; do
  [[ -f $REPO_DIR/helpers/$f ]] || continue
  cp -a "$REPO_DIR/helpers/$f" "$HOME/.local/bin/$f"
  chmod +x "$HOME/.local/bin/$f"
done

log "Installing PAM service for the lock password flow (/etc/pam.d/omarchy-lock-password)"
if [[ -r /etc/pam.d/omarchy-lock-password ]]; then
  sudo cp -a /etc/pam.d/omarchy-lock-password "/tmp/omarchy-lock-password.bak-$STAMP" 2>/dev/null || true
fi
sudo cp -a "$REPO_DIR/pam/omarchy-lock-password" /etc/pam.d/omarchy-lock-password

# ---------------------------------------------------------------------------
# 3. Extra bar widgets (ii-clock, system-monitor; ii-workspaces ships in shell/)
#    Third-party plugins live in ~/.config/omarchy/plugins/ (scanned by the shell).
# ---------------------------------------------------------------------------
log "Installing extra bar widgets"
mkdir -p "$HOME/.config/omarchy/plugins"
for p in trevor.ii-clock trevor.system-monitor trevor.ii-workspaces; do
  [[ -d $REPO_DIR/plugins/$p ]] || continue
  cp -a "$REPO_DIR/plugins/$p" "$HOME/.config/omarchy/plugins/"
done

# ---------------------------------------------------------------------------
# 4. Idle service: ensure the niri build (no Quickshell.Hyprland dependency)
# ---------------------------------------------------------------------------
log "Ensuring the niri idle service is installed"
IDLE_DIR="$PORT_DIR/shell/plugins/services/idle"
if [[ -d $IDLE_DIR ]]; then
  cp -a "$IDLE_DIR/Service.qml" "$IDLE_DIR/Service.qml.bak-$STAMP" 2>/dev/null || true
  cp -a "$REPO_DIR/shell/plugins/services/idle/Service.qml" "$IDLE_DIR/Service.qml"
fi

log "Done. Restart the shell (omarchy-shell-niri) so fonts/widgets/idle load."
echo
echo "  Idle behaviour comes from shell.json -> idle { screensaver:150, lock:300 }."
echo "  Lock manually:  omarchy system lock   (or omarchy-system-lock)"
echo "  NOTE: idle will NOT fire while an app holds a zwp_idle_inhibitor (by design)."
