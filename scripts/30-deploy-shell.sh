#!/bin/bash
# 30-deploy-shell.sh
#
# Deploys the ported Omarchy quickshell bar, its config, the Ubuntu helper
# stubs, the omarchy-* driver scripts, the niri config, and the systemd user
# units. All writes are backed up first; nothing is clobbered blindly.
#
#   ./30-deploy-shell.sh
#
# Run as your normal user (no sudo needed for the user-level files; it will
# sudo only to create /opt/omarchy-port if it isn't already user-owned).
#
# Layout it produces:
#   ~/omarchy-port/            <- the ported shell tree (OMARCHY_PATH)
#   ~/.local/bin/              <- omarchy-* drivers + Ubuntu helper stubs
#   ~/.config/niri/config.kdl  <- niri config with the Omabuntu binds
#   ~/.config/omarchy/shell.json
#   ~/.config/systemd/user/    <- elephant.service + wall-kiosk units
#   ~/.config/omarchy/hooks/   <- wall-kiosk theme hooks
#
# Idempotent: re-running re-copies files (after backing up the previous
# version) and re-arms the units.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT_DIR="$HOME/omarchy-port"
BIN_DIR="$HOME/.local/bin"
STAMP="$(date +%Y%m%d-%H%M%S)"

log() { printf '\n==> %s\n' "$*"; }
backup_and_copy() { # src dst
  local src=$1 dst=$2
  mkdir -p "$(dirname "$dst")"
  [[ -e $dst ]] && cp -a "$dst" "$dst.bak-$STAMP"
  cp -a "$src" "$dst"
}

log "Repo: $REPO_DIR"
log "Port dir (OMARCHY_PATH): $PORT_DIR"

# ---------------------------------------------------------------------------
# 1. Shell tree -> ~/omarchy-port/shell, config -> ~/omarchy-port/config
# ---------------------------------------------------------------------------
log "Deploying the ported shell tree"
mkdir -p "$PORT_DIR"
# Replace the shell tree (it is versioned here; the VM copy is the source).
if [[ -d $PORT_DIR/shell ]]; then
  mv "$PORT_DIR/shell" "$PORT_DIR/shell.bak-$STAMP"
fi
cp -a "$REPO_DIR/shell" "$PORT_DIR/shell"

# themes live under OMARCHY_PATH/themes for the built-in theme set. We do NOT
# vendor the 22 upstream themes (120 MB) - `omarchy theme list` falls back to
# $OMARCHY_PATH/themes, but the upstream set should come from upstream Omarchy.
# Only the port-specific wall-kiosk theme is deployed (see step 4).
mkdir -p "$PORT_DIR/themes"

# ---------------------------------------------------------------------------
# 2. omarchy-* drivers + Ubuntu helper stubs -> ~/.local/bin
# ---------------------------------------------------------------------------
log "Installing omarchy-* drivers and helper stubs into $BIN_DIR"
mkdir -p "$BIN_DIR"
for f in "$REPO_DIR"/omarchy-bin/*; do
  backup_and_copy "$f" "$BIN_DIR/$(basename "$f")"
done
for f in "$REPO_DIR"/helpers/*; do
  backup_and_copy "$f" "$BIN_DIR/$(basename "$f")"
done
chmod +x "$BIN_DIR"/omarchy-* 2>/dev/null || true

# The port's shell launcher hardcodes OMARCHY_PATH. Rewrite it to this host's
# port dir so the same repo works on a different machine/username.
log "Pointing omarchy-shell-niri at $PORT_DIR"
sed -i "s|^export OMARCHY_PATH=.*|export OMARCHY_PATH=$PORT_DIR|" "$BIN_DIR/omarchy-shell-niri"
sed -i "s|\$HOME/omarchy-port|$PORT_DIR|g" "$BIN_DIR/omarchy-shell-niri"

# Make sure ~/.local/bin is on PATH for the graphical session.
for rc in "$HOME/.bashrc" "$HOME/.profile"; do
  [[ -f $rc ]] || continue
  grep -q 'omarchy-niri-ubuntu' "$rc" || \
    printf '\n# Added by omarchy-niri-ubuntu\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
done

# ---------------------------------------------------------------------------
# 3. niri config + omarchy shell.json
# ---------------------------------------------------------------------------
log "Deploying niri config.kdl"
mkdir -p "$HOME/.config/niri"
# Point the shell spawn path at this host's ~/.local/bin (config ships "%h/...").
sed "s|%h/.local/bin|$HOME/.local/bin|g" \
  "$REPO_DIR/config/config.kdl" > "$PORT_DIR/config.kdl.tmp"
backup_and_copy "$PORT_DIR/config.kdl.tmp" "$HOME/.config/niri/config.kdl"
rm -f "$PORT_DIR/config.kdl.tmp"
niri validate -c "$HOME/.config/niri/config.kdl" && echo "niri config valid"

log "Deploying omarchy shell.json"
mkdir -p "$HOME/.config/omarchy"
backup_and_copy "$REPO_DIR/config/shell.json" "$HOME/.config/omarchy/shell.json"

# ---------------------------------------------------------------------------
# 4. wall-kiosk theme + systemd user units + hooks
# ---------------------------------------------------------------------------
log "Installing the wall-kiosk theme"
mkdir -p "$HOME/.config/omarchy/themes"
THEME_DST="$HOME/.config/omarchy/themes/wall-kiosk"
if [[ -d $THEME_DST ]]; then
  mv "$THEME_DST" "$THEME_DST.bak-$STAMP"
fi
cp -a "$REPO_DIR/theme/wall-kiosk" "$THEME_DST"
chmod +x "$THEME_DST/bin/"*.sh "$THEME_DST/bin/"*.py 2>/dev/null || true
# Run the theme's own installer (installs units + hooks, idempotent).
"$THEME_DST/install.sh"

log "Installing elephant.service (Walker app spawner) + walker restart drop-in"
mkdir -p "$HOME/.config/systemd/user"
backup_and_copy "$REPO_DIR/systemd/elephant.service" "$HOME/.config/systemd/user/elephant.service"
mkdir -p "$HOME/.config/systemd/user/app-walker@autostart.service.d"
backup_and_copy "$REPO_DIR/systemd/app-walker@autostart.service.d-restart.conf" \
  "$HOME/.config/systemd/user/app-walker@autostart.service.d/restart.conf"

# elephant must (re)start with the graphical session so it never holds a stale
# niri socket / missing WAYLAND_DISPLAY (the Walker "apps don't launch" bug).
mkdir -p "$HOME/.config/systemd/user/graphical-session.target.wants"
ln -sf "$HOME/.config/systemd/user/elephant.service" \
  "$HOME/.config/systemd/user/graphical-session.target.wants/elephant.service"
systemctl --user daemon-reload
systemctl --user enable elephant.service 2>/dev/null || true

log "Done."
echo
echo "Next:"
echo "  ./40-wire-session.sh   (spawn wiring for the niri session, run once per session/login)"
echo "  ./50-verify.sh         (sanity checks)"
echo "Then log out and pick the 'Niri' session in GDM."
