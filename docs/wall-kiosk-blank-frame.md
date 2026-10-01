# wall-kiosk live-capture wallpaper

`theme/wall-kiosk/` is a port-specific Omarchy theme that turns the desktop
wallpaper into a **live capture of a dashboard URL**, refreshed every 30 s.

## Pieces

- `wall-kiosk.env` — `WALL_KIOSK_URL` / `WALL_KIOSK_WIDTH` / `WALL_KIOSK_HEIGHT` / `WALL_KIOSK_SETTLE`.
- `bin/wall-kiosk-capture.py` — CDP-driven headless Chromium screenshot.
- `bin/wall-kiosk-refresh.sh` — alternates `live-a.png`/`live-b.png` and calls `omarchy-theme-bg-set`.
- `systemd/wall-kiosk-capture.{service,timer}` — 30 s oneshot timer.
- `hooks/theme-set.d/wall-kiosk-capture-toggle` — start/stop the timer on theme switch.
- `hooks/post-boot.d/wall-kiosk-capture-resume` — restart the timer at login if active.
- `install.sh` / `uninstall.sh` — install/remove the units + hooks.

## Why CDP, not `chromium --headless --screenshot`

The outer dashboard page loads instantly, but it fetches its config via JS and
then sets an `<iframe id="display" src=...>` **asynchronously**, after the outer
page's `load` event. `--screenshot` fires at `load` and always captures a blank
frame. `--virtual-time-budget` was tried and **deadlocks** against the page's
open EventSource (SSE) connection. So the capture script drives navigation over
the DevTools Protocol and waits for the iframe to actually be ready.

## Why the alternating filenames

Omarchy's background renderer compares the new background's **path string** to
the current one to decide whether to run its reveal transition. Reusing a single
filename looks like "no change" and the on-screen image never refreshes. The
refresh script alternates `live-a.png` / `live-b.png` each tick.

## The blank-frame bug (fixed)

An earlier version did a blind `time.sleep(SETTLE)` after `Page.navigate` and
then captured. On a cold Chromium start the iframe often wasn't ready within the
settle window, producing ~26 KB blank frames about half the time (real frames are
1.9–4.4 MB). A blank frame applied as wallpaper looks like the desktop is
"stuck"/black. The shipped `bin/wall-kiosk-capture.py` fixes this by:

1. **Readiness wait** — poll over CDP until `<iframe id="display">` has a
   non-empty `src` and its document is `readyState === "complete"` with body
   children, *then* apply the settle delay.
2. **Blank-frame retry** — if the captured PNG is < 200 KB (blank), re-wait and
   retry within a 25 s deadline, then fail rather than apply a blank.

Verified: 6/6 manual captures 2.1–3.7 MB, zero blanks; 5 consecutive timer ticks
all differed (wallpaper advances); atomic write via `.tmp` + `os.replace`;
non-zero exit on failure so a bad capture never clobbers the last good image.

## Caveats

- The **first** capture after the timer (re)starts can still be blank/small
  (cold-start Chromium + SSE not yet connected); it self-heals on the next tick.
- The kiosk's *displayed* photo advances on the kiosk's own schedule; the 30 s
  timer refreshes the *capture*, not the photo.
- `Linger=no`: the timer runs while the user is logged in (matches the
  `PartOf=graphical-session.target` design).
- Requires `chromium` and the Python `websocket-client` package.
