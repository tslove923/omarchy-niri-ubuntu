# GUIDE: Omarchy shell on Ubuntu 24.04 + niri

A human **or** an agent can follow this end-to-end on a fresh Ubuntu 24.04 box.
Read the whole thing first if you value your time — the pitfalls section
explains the failures we already debugged so you don't repeat them.

---

## 0. Prerequisites

- **Ubuntu 24.04 LTS (noble)**, x86_64.
- A **desktop-capable machine**. Wayland + Qt Quick needs a real GPU driver
  (Intel/AMD/NVIDIA or a VM with virtio-gpu/3D accel). A machine that can't run
  a Wayland session at all cannot run this.
- A normal **desktop user with sudo** (do *not* build as root; the scripts sudo
  internally).
- **~6 GB** free disk (Qt 6.8.3 ≈ 1.5 GB, quickshell build ≈ 2–3 GB, plus deps).
- **Internet**: apt, the lengau Qt PPA, `download.qt.io`, GitHub, `herdr.dev`.
- Know your **terminal** and be ready to **log out / log in** a few times.

Optional but expected by the binds: `xdg-terminal-exec`, `alacritty`, `chromium`,
`herdr`, `tmux` — all installed by stage 20.

---

## 1. Install Omabuntu (stage 00)

Omabuntu is the Ubuntu port of Omarchy. Upstream installer:

```bash
./scripts/00-install-omabuntu.sh
# which runs:  curl -fsSL https://omakub.org/install.sh | bash
```

> The canonical URL is `https://omakub.org/install.sh` (it redirects to
> `https://omarchy.org/omakub/`). Verified reachable 2026-10-01. Do **not**
> guess a different URL.

This installs the Omakub base (packages, `~/.local/share/omakub`, the
`omakub-*` CLI). It assumes a GNOME/Ubuntu desktop and **does not** install niri
or the Omarchy quickshell — those are stages 10/20/30.

**Verify:** `command -v omakub-menu` prints a path; `ls ~/.local/share/omakub`
exists.

---

## 2. Qt 6.8.3 + quickshell (stage 10) — the hard part

Ubuntu 24.04 ships Qt 6.4/6.6. The Omarchy shell needs **Qt 6.8+** (the
`isTransient` property on `Notification`, newer QtQuick/Wayland APIs). Against
Ubuntu's Qt the shell fails to parse or crashes. We therefore build an official
Qt 6.8.3 and link quickshell against it.

```bash
./scripts/10-install-qt-quickshell.sh
```

What it does, in order:

1. `apt` build deps + adds the **lengau/qt6-backports** PPA (provides
   `qt6-base-private-dev` built for noble — quickshell's build needs private Qt
   headers).
2. Installs **aqtinstall** and fetches **official Qt 6.8.3** (`linux_gcc_64`)
   into `/opt/Qt/6.8.3/gcc_64` with the modules
   `qtdeclarative qtwayland qtsvg qtshadertools qt5compat qtimageformats
   qtwaylandcompositor qtquick3d`.
3. Clones **quickshell v0.3.1** and builds it with
   `-DCMAKE_PREFIX_PATH=/opt/Qt/6.8.3/gcc_64` and `-DVENDOR_CPPTRACE=ON`.
4. Installs the **build-tree** binary to `/usr/local/bin/quickshell` (see
   pitfall #2), sets `/etc/ld.so.conf.d/qt6-8-3.conf`, and writes
   `/etc/profile.d/qt6-8-3.sh` with the Qt plugin/QML import paths.

**Verify:**
```bash
/usr/local/bin/quickshell --version    # -> Quickshell 0.3.1 ...
/opt/Qt/6.8.3/gcc_64/bin/qmake --version   # -> Qt 6.8.3
ldd /usr/local/bin/quickshell | grep -c 'not found'   # -> 0
```

---

## 3. niri + GDM session + CLI deps (stage 20)

```bash
./scripts/20-install-niri-session.sh
```

- Installs **niri** (the working reference used the omakasui package repo:
  `packages.omakasui.org`; the `xtradeb/apps` PPA is an alternative).
- Installs CLI deps the shell shells out to: `xdg-terminal-exec`,
  `libxkbcommon-tools` (provides `xkbcli`), `inotify-tools` (`inotifywait`),
  `chromium`, `alacritty`, `ddcutil`, `brightnessctl`, `tmux`, `grim`,
  `wl-clipboard`.
- Installs **herdr** from `https://herdr.dev/install.sh`.
- Nudges you to install a **Nerd Font** (the bar's icon glyphs render as tofu
  without one).
- Registers niri as an **on-demand GDM session**:
  - `niri.service` stays `static` and **unmasked**.
  - GDM autologin **off**, `DefaultSession=niri`.
  - `wayvnc.service` autostart disabled (it needs a running niri session).

**Verify:** `niri --version`; `grep DefaultSession /etc/gdm3/custom.conf` → `niri`.

---

## 4. Deploy the ported shell (stage 30)

```bash
./scripts/30-deploy-shell.sh
```

- Copies `shell/` → `~/omarchy-port/shell` (this is `OMARCHY_PATH`).
- Installs `omarchy-bin/*` + `helpers/*` → `~/.local/bin` (backing up any
  existing file with a `.bak-<timestamp>` suffix).
- Installs `config/config.kdl` → `~/.config/niri/config.kdl` and validates it
  with `niri validate`.
- Installs `config/shell.json` → `~/.config/omarchy/shell.json`.
- Installs the `wall-kiosk` theme and runs its `install.sh` (units + hooks).
- Installs `elephant.service` (Walker's app spawner) with its
  `PartOf=graphical-session.target` fix and enables it.

**Verify:** `niri validate -c ~/.config/niri/config.kdl` is silent/OK; the files
exist under `~/.local/bin`, `~/.config/niri`, `~/.config/omarchy`.

---

## 5. First login into niri

1. **Log out** of GNOME.
2. At GDM, click the **gear / session** icon and choose **Niri**.
3. Log in. You should get a bare niri desktop (no bar yet — the shell isn't
   wired/started until stage 40).
4. Open a terminal. Under niri the default terminal bind is `Mod+Return`
   (`xdg-terminal-exec`). If that isn't set yet, use the `niri-session`'s own
   default terminal, or `Ctrl+Alt+F2` console if truly stuck.

---

## 6. Wire + verify the session (stages 40, 50)

Inside the niri session:

```bash
cd omarchy-niri-ubuntu
./install.sh --finish      # = 40-wire-session.sh + 50-verify.sh
```

- Stage 40 installs `omarchy-shell-niri.service` (a systemd user unit that
  starts the bar with the graphical session), starts it, and confirms
  `elephant` carries the **live** session env.
- Stage 50 runs read-only PASS/FAIL checks. Everything green = you're done.

**What a working bar looks like:** a top bar with, left→right: Omarchy menu
button, the ii-workspaces pill; center: indicators, clock, keyboard layout,
weather, system-update; right: tray, agents, bluetooth, network, audio, monitor,
power. `Mod+Space` opens the Walker launcher; selecting an app (e.g. Alacritty)
launches it.

---

## 7. Optional: the live-capture wallpaper theme (`wall-kiosk`)

Stage 30 already installs the theme. To use it:

```bash
# point it at YOUR dashboard (it ships a placeholder URL):
$EDITOR ~/.config/omarchy/themes/wall-kiosk/wall-kiosk.env   # WALL_KIOSK_URL=...
systemctl --user daemon-reload

omarchy-theme-set wall-kiosk      # switches theme; theme-set hook starts the timer
```

It captures the URL with headless Chromium over CDP every 30 s and applies the
frame as the background. Switching to any other theme stops the timer
automatically (theme-set hook), and `post-boot` resumes it if wall-kiosk is
active at login.

**Verify:** `systemctl --user status wall-kiosk-capture.timer` is active;
`journalctl --user -u wall-kiosk-capture -n 20` shows
`wrote .../live-a.png (... bytes)`; the wallpaper changes within ~30 s.

---

## Pitfalls (all hit and fixed on the reference system)

### 1. niri session collision → grey screen / login loop
Running niri as a **boot-time systemd user service** makes GDM login fail with
`A niri session is already running`; the session never registers.
**Do:** keep `niri.service` `static` + **unmasked** and let `niri-session` start
it at login; disable GDM autologin.
**Do NOT** `systemctl --user mask niri.service` — `niri-session` starts the
compositor via `systemctl --user start niri.service`, so masking it breaks login
entirely (we did this; it cost a session).

### 2. quickshell binary must be the build-tree copy, not `cmake --install`
`cmake --install` strips the RUNPATH, so the installed binary can't find
`/opt/Qt/6.8.3/gcc_64/lib` at runtime. Install the **build-tree** binary:
`install -m0755 build/src/quickshell /usr/local/bin/quickshell`, plus the
`/etc/ld.so.conf.d` entry. Stage 10 does this.

### 3. aqt module names
`qtdeclarative`, `qtsvg`, `qtwayland` are **not** valid aqt module names for
6.8.x and abort the install. Use
`-m qtdeclarative qtwayland qtsvg qtshadertools qt5compat qtimageformats qtwaylandcompositor qtquick3d`.

### 4. Qt parse errors (`isTransient`)
On Ubuntu's Qt the shell hits a parse error at
`plugins/notifications/Service.qml` (`transient` is a Qt 6.8 keyword; the shell
uses `isTransient`). This is *the* reason for the Qt 6.8.3 build — don't try to
patch around it.

### 5. Missing icon font → tofu glyphs
No Nerd Font ⇒ the bar shows boxes instead of icons. Install one (e.g.
CaskaydiaMono Nerd Font) and `fc-cache -f`.

### 6. Walker launches nothing ("apps don't launch") — elephant stale env
`elephant.service` (Walker's data provider + app spawner) had **no**
`PartOf=graphical-session.target`. After a session restart it kept running with
the **previous** session's `NIRI_SOCKET` and **no `WAYLAND_DISPLAY`**, so it
spawned GUI apps into a dead environment; they died instantly and silently.
**Fix:** `PartOf=graphical-session.target` + `Restart=always`, and have it start
with the session (`systemd/elephant.service`). `50-verify.sh` asserts elephant
has a live `WAYLAND_DISPLAY`.

### 7. mako squatting the notification bus
If `mako` is set as `spawn-at-startup` in `config.kdl`, it owns
`org.freedesktop.Notifications` and fights the Omarchy toasts. The shipped
`config.kdl` does not spawn mako.

### 8. Duplicate niri binds → validation failure
`niri validate` rejects duplicate chords. The Omabuntu set reserves
`Mod+Shift+Space` (input source) and uses `Mod+Shift+F` for the float toggle —
don't also bind the editor there. The shipped `config.kdl` is deduped.

### 9. wall-kiosk blank frames
A blind `sleep` after navigation screenshots Chromium's blank `about:blank`
(~25 KB) because the dashboard sets its `<iframe src>` asynchronously, and
`--virtual-time-budget` deadlocks against the page's SSE. The shipped
`bin/wall-kiosk-capture.py` waits for the iframe to actually load and retries
blank captures. (See `docs/wall-kiosk-blank-frame.md`.)

### 10. `OMARCHY_PATH` must be set for the session
The shell driver (`omarchy-shell-niri`) exports `OMARCHY_PATH=~/omarchy-port`
and the Qt QML import paths. If you launch quickshell by hand without these, the
bar won't find its QML modules. Use the systemd unit (stage 40) or the driver.

---

## What is verified vs. untested

**Verified (on the reference Ubuntu 24.04 + niri machine):**
- The shell tree, config, helpers, omarchy-bin drivers, units, and theme files
  are byte-for-byte the ones that produced a working bar.
- `niri validate` passes on the shipped `config.kdl`.
- Walker end-to-end launch works after the elephant fix.
- The wall-kiosk timer captures and applies fresh frames; theme switching
  starts/stops it.
- `50-verify.sh`'s checks all passed there.

**Untested end-to-end on a fresh machine:** the install scripts were assembled
from the reference system's state, not executed against a blank Ubuntu 24.04.
Expect to read output and adjust package names if Ubuntu's repos move. The
scripts back up before overwriting and are safe to re-run.

## Secret / privacy note

No tokens, keys, or credentials are in this repo. The reference wall-kiosk URL,
hostnames, and the personal IP were replaced with placeholders in the shipped
files — set `WALL_KIOSK_URL` in `wall-kiosk.env` yourself.
