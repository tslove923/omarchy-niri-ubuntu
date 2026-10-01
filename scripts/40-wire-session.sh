#!/bin/bash
# 40-wire-session.sh
#
# Wires the ported shell into the running niri session and verifies the pieces
# that only make sense inside a live graphical session:
#   * a systemd user unit that starts the Omarchy quickshell bar (so it comes up
#     with the session, not from a hand-typed command)
#   * confirm elephant (Walker's spawner) is running with the LIVE session env
#   * (re)start the quickshell bar
#
# Run this INSIDE the niri session (a terminal in the niri desktop), as your
# normal user. Safe to re-run.
#
#   ./40-wire-session.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT_DIR="$HOME/omarchy-port"
STAMP="$(date +%Y%m%d-%H%M%S)"

log() { printf '\n==> %s\n' "$*"; }

if [[ -z ${WAYLAND_DISPLAY:-} && -z ${NIRI_SOCKET:-} ]]; then
  echo "WARNING: no WAYLAND_DISPLAY/NIRI_SOCKET in env. Run this from inside the" >&2
  echo "         niri session for the full wiring to work." >&2
fi

# ---------------------------------------------------------------------------
# 1. systemd user unit that launches the ported quickshell bar with the session
# ---------------------------------------------------------------------------
log "Installing omarchy-shell-niri.service (session bar autostart)"
UNIT="$HOME/.config/systemd/user/omarchy-shell-niri.service"
mkdir -p "$HOME/.config/systemd/user"
[[ -e $UNIT ]] && cp -a "$UNIT" "$UNIT.bak-$STAMP"
cat > "$UNIT" <<EOF
[Unit]
Description=Omarchy quickshell bar (niri Ubuntu port)
PartOf=graphical-session.target
After=graphical-session.target
ConditionEnvironment=WAYLAND_DISPLAY

[Service]
Type=simple
Environment=OMARCHY_PATH=$PORT_DIR
Environment=QT_PLUGIN_PATH=/opt/Qt/6.8.3/gcc_64/plugins
Environment=QML2_IMPORT_PATH=/opt/Qt/6.8.3/gcc_64/qml:/usr/lib/x86_64-linux-gnu/qt6/qml
Environment=QML_IMPORT_PATH=/opt/Qt/6.8.3/gcc_64/qml:/usr/lib/x86_64-linux-gnu/qt6/qml
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/local/bin/quickshell -p $PORT_DIR/shell/shell.qml
Restart=on-failure
RestartSec=2

[Install]
WantedBy=graphical-session.target
EOF
systemctl --user daemon-reload
systemctl --user enable omarchy-shell-niri.service 2>/dev/null || true

# If niri spawns the shell directly (spawn-at-startup in config.kdl), the unit
# above and that spawn can race. Prefer the systemd unit: comment out the
# spawn-at-startup line so only one shell instance owns the IPC socket.
CFG="$HOME/.config/niri/config.kdl"
if [[ -f $CFG ]] && grep -q '^spawn-at-startup ".*omarchy-shell-niri"' "$CFG"; then
  log "Disabling spawn-at-startup of the shell (systemd unit owns it now)"
  cp -a "$CFG" "$CFG.bak-unitspawn-$STAMP"
  sed -i 's|^spawn-at-startup ".*omarchy-shell-niri"|// moved to omarchy-shell-niri.service|' "$CFG"
  niri validate -c "$CFG" && echo "niri config valid"
fi

# ---------------------------------------------------------------------------
# 2. Restart / start the bar
# ---------------------------------------------------------------------------
log "Starting the Omarchy quickshell bar"
systemctl --user restart omarchy-shell-niri.service 2>&1 | tail -2 || true
sleep 3
systemctl --user --no-pager status omarchy-shell-niri.service 2>&1 | head -8 || true

# ---------------------------------------------------------------------------
# 3. elephant (Walker spawner): ensure live session env
# ---------------------------------------------------------------------------
log "Checking elephant (Walker app spawner) session env"
if systemctl --user is-active elephant.service >/dev/null 2>&1; then
  EPID="$(systemctl --user show -p MainPID --value elephant.service)"
  echo "elephant pid=$EPID"
  echo "--- env (WAYLAND_DISPLAY / NIRI_SOCKET) ---"
  tr '\0' '\n' < "/proc/$EPID/environ" 2>/dev/null | grep -E '^(WAYLAND_DISPLAY|NIRI_SOCKET)=' || true
else
  echo "elephant not active; starting it (PartOf=graphical-session.target)"
  systemctl --user start elephant.service 2>&1 | tail -2 || true
fi

log "Done. The bar should be visible at the top of the screen."
echo "If not:  journalctl --user -u omarchy-shell-niri.service -n 40 --no-pager"
