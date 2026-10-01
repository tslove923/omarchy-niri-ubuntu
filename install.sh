#!/bin/bash
# install.sh - top-level bootstrap for the Omarchy-on-Ubuntu/niri port.
#
# Takes a FRESH Ubuntu 24.04 to "niri + ported Omarchy quickshell bar".
#
#   ./install.sh            # interactive; runs stages 00..50
#   ./install.sh --check    # only run the dependency/state check (no changes)
#
# Stages (each is a separate script under scripts/ and can be run alone):
#   00-install-omabuntu.sh      Omabuntu (omakub) on Ubuntu
#   10-install-qt-quickshell.sh Qt 6.8.3 + quickshell build (sudo)
#   20-install-niri-session.sh  niri + GDM on-demand session + CLI deps (sudo)
#   30-deploy-shell.sh          ported shell, config, helpers, units
   35-install-ui-extras.sh     fonts, lock+idle, extra bar widgets
#   40-wire-session.sh          session wiring (run INSIDE niri)
#   50-verify.sh                read-only verification
#
# Stages 00-30 run from a normal GNOME/console shell. Stage 40 needs a live
# niri session, so the runner stops and asks you to log into niri first.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-run}"

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
}

case "$MODE" in
  -h|--help) usage; exit 0 ;;
  --finish)
    log "Stage 40 - wire the live niri session"
    bash "$HERE/scripts/40-wire-session.sh"
    log "Stage 50 - verify"
    bash "$HERE/scripts/50-verify.sh"
    exit $? ;;
  --check)
    log "Dependency / state check (read-only)"
    bash -c '
      say() { printf "  %-34s %s\n" "$1" "$2"; }
      say "os"          "$(grep -oP "(?<=^PRETTY_NAME=\").*(?=\")" /etc/os-release 2>/dev/null)"
      say "niri"        "$(command -v niri || echo MISSING)"
      say "quickshell"  "$(command -v quickshell || echo MISSING)"
      say "Qt 6.8.3"    "$([ -x /opt/Qt/6.8.3/gcc_64/bin/qmake ] && echo present || echo MISSING)"
      say "omabuntu"    "$([ -d ~/.local/share/omakub ] && echo present || echo MISSING)"
      say "chromium"    "$(command -v chromium || echo MISSING)"
      say "alacritty"   "$(command -v alacritty || echo MISSING)"
      say "xkbcli"      "$(command -v xkbcli || echo MISSING)"
      say "inotifywait" "$(command -v inotifywait || echo MISSING)"
      say "herdr"       "$(command -v herdr || echo MISSING)"
    '
    exit 0 ;;
esac

if [[ $EUID -eq 0 ]]; then
  echo "Do not run install.sh as root. Run as your normal desktop user." >&2
  exit 1
fi

log "Stage 00 - Omabuntu"
bash "$HERE/scripts/00-install-omabuntu.sh"

log "Stage 10 - Qt 6.8.3 + quickshell (sudo)"
bash "$HERE/scripts/10-install-qt-quickshell.sh"

log "Stage 20 - niri + GDM session + CLI deps (sudo)"
bash "$HERE/scripts/20-install-niri-session.sh"

log "Stage 30 - deploy ported shell/config/helpers"
bash "$HERE/scripts/30-deploy-shell.sh"
bash "$HERE/scripts/35-install-ui-extras.sh"

cat <<'EOF'

============================================================================
Stages 00-30 are done. Now:
  1. Log out of GNOME.
  2. At the GDM login screen, pick the gear icon and choose the "Niri" session.
  3. Log in, open a terminal in niri, and run:

       ./install.sh --finish

  (that runs 40-wire-session.sh + 50-verify.sh inside the live session)
============================================================================
EOF
