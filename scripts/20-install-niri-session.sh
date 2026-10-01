#!/bin/bash
# 20-install-niri-session.sh
#
# Installs the niri Wayland compositor and registers it as an ON-DEMAND GDM
# session, then installs the per-app CLI dependencies the ported shell needs.
#
#   ./20-install-niri-session.sh
#
# Requires sudo. Run as your normal user.
#
# Why "on-demand": during the port we accidentally ran niri as a boot-time
# systemd USER service. GDM login then hit "A niri session is already running"
# and the session never registered -> grey screen / login loop. The correct
# setup is:
#   * niri.service stays `static` + UNMASKED (niri-session starts it at login)
#   * GDM autologin OFF, DefaultSession=niri
# Do NOT mask niri.service: `niri-session` starts the compositor via
# `systemctl --user start niri.service`, so a masked unit breaks login entirely.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

log() { printf '\n==> %s\n' "$*"; }

if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user; the script uses sudo where needed." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. niri
# ---------------------------------------------------------------------------
# niri on noble was installed from the omakasui package repo
# (https://packages.omakasui.org), which builds niri for Ubuntu 24.04.
# The xtradeb/apps PPA also carries a noble niri build. We add the omakasui
# repo (the one the working VM uses) and install niri.
log "Installing niri"
if ! command -v niri >/dev/null 2>&1; then
  if ! grep -rq "packages.omakasui.org" /etc/apt/sources.list.d/ 2>/dev/null; then
    sudo install -d -m 0755 /etc/apt/keyrings
    # omakasui repo key
    curl -fsSL https://packages.omakasui.org/key.asc | \
      sudo gpg --dearmor -o /etc/apt/keyrings/omakasui.gpg 2>/dev/null || \
      curl -fsSL https://packages.omakasui.org/pubkey.gpg | \
      sudo gpg --dearmor -o /etc/apt/keyrings/omakasui.gpg
    echo "deb [signed-by=/etc/apt/keyrings/omakasui.gpg] https://packages.omakasui.org noble main" | \
      sudo tee /etc/apt/sources.list.d/omakasui.sources >/dev/null
  fi
  sudo apt-get update -qq
  sudo apt-get install -y -qq niri
fi
log "niri: $(niri --version 2>&1 | head -1)"

# ---------------------------------------------------------------------------
# 2. Per-app CLI deps the ported Omarchy shell shells out to
# ---------------------------------------------------------------------------
log "Installing shell CLI dependencies"
sudo apt-get install -y -qq \
  xdg-terminal-exec \
  libxkbcommon-tools \
  inotify-tools \
  chromium \
  alacritty \
  ddcutil \
  brightnessctl \
  tmux \
  grim \
  wl-clipboard \
  notify-osd || true
# note: `xdg-terminal-exec` gives Mod+Return a terminal; `xkbcli`
# (libxkbcommon-tools) is what the bar's keyboard-layout widget calls;
# inotifywait (inotify-tools) drives config reloads.

# ---------------------------------------------------------------------------
# 3. herdr (agent terminal multiplexer) - optional but baked into binds
# ---------------------------------------------------------------------------
if ! command -v herdr >/dev/null 2>&1; then
  log "Installing herdr from https://herdr.dev/install.sh"
  curl -fsSL https://herdr.dev/install.sh | sh || \
    echo "WARNING: herdr install failed (optional; the Mod+Ctrl+Return bind will no-op)"
fi

# ---------------------------------------------------------------------------
# 4. Nerd Font (icon glyphs in the bar render as tofu without it)
# ---------------------------------------------------------------------------
log "Installing Nerd Fonts (icon glyphs)"
sudo apt-get install -y -qq fonts-cascadia-code 2>/dev/null || true
if ! fc-list 2>/dev/null | grep -qi "nerd font"; then
  echo "NOTE: no Nerd Font detected. The bar's icon glyphs need one"
  echo "      (e.g. CaskaydiaMono Nerd Font). Install e.g.:"
  echo "        mkdir -p ~/.local/share/fonts && cd ~/.local/share/fonts"
  echo "        curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaMono.zip"
  echo "        unzip CascadiaMono.zip && fc-cache -f"
fi

# ---------------------------------------------------------------------------
# 5. niri as an ON-DEMAND GDM session (NOT a boot-time user service)
# ---------------------------------------------------------------------------
log "Registering niri as a GDM session"
# The niri package ships /usr/share/wayland-sessions/niri.desktop and
# /usr/lib/systemd/user/niri.service. Nothing to install; just make sure the
# service is unmasked and NOT enabled as a boot service.
systemctl --user unmask niri.service 2>/dev/null || true
if systemctl --user is-enabled niri.service >/dev/null 2>&1; then
  log "niri.service was enabled as a boot user service - disabling it"
  systemctl --user disable niri.service || true
fi

log "Setting GDM DefaultSession=niri and disabling autologin"
sudo cp /etc/gdm3/custom.conf "/etc/gdm3/custom.conf.bak-$(date +%Y%m%d-%H%M%S)"
if ! grep -q "^DefaultSession=niri" /etc/gdm3/custom.conf; then
  if grep -q "^DefaultSession=" /etc/gdm3/custom.conf; then
    sudo sed -i 's/^DefaultSession=.*/DefaultSession=niri/' /etc/gdm3/custom.conf
  else
    sudo sed -i '/^\[daemon\]/a DefaultSession=niri' /etc/gdm3/custom.conf
  fi
fi
# Turn autologin OFF (comment the exact lines; preserves everything else).
sudo sed -i 's/^AutomaticLoginEnable=true/#AutomaticLoginEnable=true/; s/^AutomaticLogin='"/$USER"'/#AutomaticLogin='"$USER"'/' /etc/gdm3/custom.conf

log "GDM config:"
grep -nE "DefaultSession|AutomaticLogin" /etc/gdm3/custom.conf || true

# wayvnc (if present) needs a running niri session; disable its autostart so it
# doesn't fight the on-demand session model.
systemctl --user disable wayvnc.service 2>/dev/null || true

log "Done. Next: run ./30-deploy-shell.sh (as your user), then log into a niri session."
