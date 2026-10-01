# omarchy-niri-ubuntu

Run the **Omarchy quickshell desktop shell** on **Ubuntu 24.04** with the
**niri** scrollable-tiling Wayland compositor.

Omarchy ships a beautiful Quickshell bar, but it targets Arch/Hyprland. This
repo is the reproducible port of that shell to a stock Ubuntu 24.04 box running
niri, built from a working reference system. It contains the ported shell, the
port-specific config, the Ubuntu helper/stub scripts that replace Arch-only
binaries, the Qt 6.8 + quickshell build recipe (the hard blocker), and
install scripts that take a **fresh** Ubuntu 24.04 to the same state.

## What you get

- A working Omarchy-style top bar (workspaces, clock, indicators, tray, audio,
  network, bluetooth, power, agents, …) on niri.
- The Omabuntu launcher keyset ported to niri bindings (`Mod+Space` → Walker, etc.).
- The wallpaper/theme system, including a **live-capture wallpaper** theme
  (`wall-kiosk`) that screenshots a dashboard URL every 30 s and applies it as
  the background.
- The `trevor.ii-workspaces` bar widget (illogical-impulse-style workspace pill).
- Ubuntu replacements for the Arch-only helper binaries the shell calls.

## Quick start

On a fresh Ubuntu 24.04 install:

```bash
git clone https://github.com/tslove923/omarchy-niri-ubuntu
cd omarchy-niri-ubuntu
./install.sh --check     # see what's missing (read-only)
./install.sh             # run stages 00-30
# log out, pick the "Niri" session at GDM, log in, open a terminal:
./install.sh --finish    # stage 40 (wire session) + 50 (verify)
```

See **[GUIDE.md](GUIDE.md)** for the full, step-by-step walkthrough including all
prerequisites, verification steps, and the pitfalls we hit (read that before you
debug anything).

## Repo layout

```
install.sh                  top-level runner (--check / --finish)
scripts/
  00-install-omabuntu.sh    Omabuntu (omakub) one-liner wrapper
  10-install-qt-quickshell.sh  Qt 6.8.3 (aqtinstall) + quickshell build (sudo)
  20-install-niri-session.sh   niri + GDM on-demand session + CLI deps (sudo)
  30-deploy-shell.sh        deploy shell tree, config, helpers, units
  35-install-ui-extras.sh   fonts, lock screen + idle, extra bar widgets
  40-wire-session.sh        wire into a LIVE niri session (run inside niri)
  50-verify.sh              read-only PASS/FAIL checks
shell/                      the ported Omarchy quickshell (OMARCHY_PATH/shell)
  plugins/trevor.ii-workspaces/  workspace-indicator bar widget
config/
  config.kdl                niri config with the Omabuntu keybinds
  shell.json                Omarchy bar layout
helpers/                    Ubuntu stubs for Arch-only omarchy-* binaries
omarchy-bin/                omarchy-shell, omarchy-theme-*, omarchy-hook drivers
systemd/                    elephant.service, wall-kiosk units, walker drop-in
theme/wall-kiosk/           live-capture wallpaper theme
docs/                       deeper notes on specific fixes
```

## Requirements

- Ubuntu 24.04 (noble), x86_64. A **physical machine or VM with a GPU/virtio**
  capable of running Wayland + Qt Quick.
- A desktop user with sudo. ~6 GB free for Qt + quickshell, ~120 MB for the shell.
- Internet access (Qt download, quickshell clone, apt, Omabuntu).

## Status / honesty

This is a port, not upstream. It is **tested**: all files here were taken from a
live working Ubuntu 24.04 + niri system, and `50-verify.sh` encodes the checks
that passed there. The install scripts are idempotent and back up before
overwriting, but they have **not** been run end-to-end on a *fresh* machine (they
were assembled from the reference system's state). Treat the first run as a
guided setup and read the script output. See GUIDE.md → *What is verified*.

## Credits & upstream

- [Omarchy](https://omarchy.org/) and [Omabuntu/omakub](https://omarchy.org/omakub/)
  by Basecamp / David Heinemeier Hansson — the shell, themes, and installer.
- [quickshell](https://github.com/quickshell-mirror/quickshell) — the Qt/QML shell runtime.
- [niri](https://github.com/YaLTeR/niri) — the compositor.
- Port, helper stubs, wall-kiosk theme, and ii-workspaces widget by
  [@tslove923](https://github.com/tslove923).

The 22-theme Omarchy color set is **not** vendored here (120 MB); it comes from
upstream Omarchy. Only the port-specific `wall-kiosk` theme is included.

## License

MIT — see [LICENSE](LICENSE). Upstream Omarchy/Omakub and quickshell retain their
own licenses; this repo only carries the port glue.
