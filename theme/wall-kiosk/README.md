# omarchy-wall-kiosk

An [Omarchy](https://omarchy.org) theme that turns the desktop background into a
**live capture of a wall kiosk dashboard**. Trevor runs it against the
`kiosk-shell photoframe dashboard (URL set in `wall-kiosk.env`) so the wallpaper is
always the current family photoframe — but any URL works.

A systemd user timer re-captures the dashboard every 30 seconds, and each new
frame is handed to Omarchy's normal wallpaper mechanism, so the desktop image
refreshes in place (with the theme's reveal transition) like a slow live video.

## How it works

```
wall-kiosk-capture.timer (systemd user, every 30s)
  └─ wall-kiosk-capture.service
       └─ bin/wall-kiosk-refresh.sh
            ├─ checks theme.name == "wall-kiosk" (never touch another theme's wallpaper)
            ├─ bin/wall-kiosk-capture.py  → headless Chromium (CDP) screenshot of the URL
            └─ omarchy-theme-bg-set backgrounds/live-{a,b}.png
```

Two details worth knowing:

- **CDP, not `chromium --screenshot`.** The kiosk page loads its config in JS
  and sets its `<iframe>` *after* the `load` event, so Chromium's built-in
  screenshot always captures a blank frame. The capture script drives Chromium
  over the DevTools Protocol and waits `WALL_KIOSK_SETTLE` real seconds after
  navigation before shooting. `--virtual-time-budget` deadlocks against the
  page's open SSE connection — don't go back to it.
- **Alternating filenames.** `live-a.png` / `live-b.png` are written
  alternately because Omarchy's background renderer compares the *path string*
  to decide whether to run its reveal transition. Reusing one filename would
  look like "no change" and never refresh the on-screen image.

## Prerequisites

- Omarchy (Hyprland + `omarchy` CLI)
- `chromium`
- `python-websocket-client` (`pacman -S python-websocket-client`)
- Network access to the kiosk URL

## Install

```bash
omarchy theme install <your-wall-kiosk-theme-repo>
~/.config/omarchy/themes/wall-kiosk/install.sh
```

`omarchy theme install` clones the theme and applies it; `install.sh` then
installs the two systemd user units and the two omarchy hooks, and starts the
capture timer (first capture lands ~5s later). The timer runs only while
`wall-kiosk` is the active theme — switching themes stops it, and coming back
(or logging in with it active) restarts it.

Uninstall:

```bash
~/.config/omarchy/themes/wall-kiosk/uninstall.sh
rm -rf ~/.config/omarchy/themes/wall-kiosk
```

## Configuration

Edit `wall-kiosk.env` (in the theme directory) to point the wallpaper at a
different dashboard or resize the capture, then:

```bash
systemctl --user daemon-reload
systemctl --user restart wall-kiosk-capture.timer
```

| Variable              | Default                    | Purpose                              |
|-----------------------|----------------------------|--------------------------------------|
| `WALL_KIOSK_URL`      | `https://example.invalid/kiosk-dashboard` | Dashboard to capture               |
| `WALL_KIOSK_WIDTH`    | `2560`                     | Capture width in px                  |
| `WALL_KIOSK_HEIGHT`   | `1440`                     | Capture height in px                 |
| `WALL_KIOSK_SETTLE`   | `5`                        | Seconds after nav before the shot    |

The same variables are honored if you run `bin/wall-kiosk-capture.py` by hand.
The refresh cadence lives in `systemd/wall-kiosk-capture.timer`
(`OnUnitActiveSec=30s`) — edit it there, then
`systemctl --user daemon-reload && systemctl --user restart wall-kiosk-capture.timer`.

## Notes

- The capture is a static screenshot: anything on the dashboard that only
  appears on interaction (e.g. a presence-triggered button panel) won't show.
- `backgrounds/` is a runtime directory — `live-a.png` / `live-b.png` are
  generated and git-ignored.
