#!/bin/bash
# 00-install-omabuntu.sh
#
# Bootstraps a FRESH Ubuntu 24.04 with Omabuntu (the Ubuntu port of Omarchy by
# Basecamp/37signals; project lives at https://omarchy.org/omakub/).
#
# This is intentionally a thin wrapper: we do NOT vendor the Omakub tree. The
# upstream installer is a `curl | bash` one-liner, and the port here only ADDS
# the niri session + the ported Omarchy quickshell bar on top of it.
#
# NOTE: the URL https://omakub.org/install.sh now redirects to
#       https://omarchy.org/omakub/  (verified 2026-10-01). We use the canonical
#       omarchy.org URL below; the old omakub.org URL still resolves.
#
# Run as your normal desktop user (it will sudo when needed), NOT as root:
#   ./00-install-omabuntu.sh
#
# Idempotent-ish: Omakub's own installer is rerunnable and versioned
# (~/.local/share/omakub). We skip if an install is already present unless
# FORCE=1.

set -euo pipefail

OMAKUB_URL="https://omakub.org/install.sh"
OMAKUB_DIR="$HOME/.local/share/omakub"

if [[ $EUID -eq 0 ]]; then
  echo "Do not run this as root; run as your desktop user (it will sudo when needed)." >&2
  exit 1
fi

if [[ -d $OMAKUB_DIR && ${FORCE:-0} != 1 ]]; then
  echo "Omakub already present at $OMAKUB_DIR (version: $(cat "$OMAKUB_DIR/version" 2>/dev/null || echo unknown))."
  echo "Re-run with FORCE=1 to reinstall/update."
  exit 0
fi

echo "==> Installing Omabuntu from $OMAKUB_URL"
echo "    (this will take a while and will prompt for sudo)"
echo "    NOTE: Omakub's installer assumes a GNOME/Ubuntu desktop; it does not"
echo "    install niri or the Omarchy quickshell. Those come in script 20/30."
echo
read -r -p "Continue? [y/N] " ans
[[ ${ans:-} =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

# Upstream expects the user to be running this from a shell in their GNOME
# session. We do not change that contract; just fetch and run it.
curl -fsSL "$OMAKUB_URL" | bash

echo
echo "==> Omabuntu install finished."
echo "    Verify:  command -v omakub-menu  ls ~/.local/share/omakub"
echo "    Next:    ./10-install-qt-quickshell.sh (needs sudo; builds Qt+quickshell)"
