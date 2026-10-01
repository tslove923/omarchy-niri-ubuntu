# The Ubuntu helper stubs (`helpers/`)

Omarchy's shell shells out to a set of `omarchy-*` helper binaries that live in
`/usr/share/omarchy/bin` on Arch. On Ubuntu those don't exist, so the bar logs
hundreds of "binary could not be found" warnings and several widgets silently
break. This directory contains drop-in replacements for the ones the bar
actually uses.

## How we found the set

Grep the shell tree for external commands, then `command -v` each:

```bash
grep -rhoE '(omarchy-[a-z-]+|xkbcli|inotifywait|hyprctl)' shell/ | sort -u
```

Two kinds of missing things came out of that: **real helper scripts** (network
status/band) and **stubs** for Hyprland-specific ones (audio/monitor/OSD/…).

## Disposition table

| Helper | What it is | Where |
|---|---|---|
| `omarchy-network-status` | real script; `omarchy-cmd-present` → `command -v` | `~/.local/bin` |
| `omarchy-network-band` | real script | `~/.local/bin` |
| `omarchy-monitor-state` | stub: `niri msg --json outputs` + `focused-output` | `~/.local/bin` |
| `omarchy-reminder` | stub: state files + background watcher (no systemd transient units) | `~/.local/bin` |
| `omarchy-audio-output-sink` | stub: `wpctl`/`pw-dump` instead of `pactl` | `~/.local/bin` |
| `omarchy-audio-sink-availability` | stub: `pw-dump` JSON instead of `pactl` | `~/.local/bin` |
| `omarchy-audio-tuning` | stub: reports no tuning (`fronted-sink` → exit 1) | `~/.local/bin` |
| `omarchy-notification-send` | stub: `notify-send` instead of raw busctl | `~/.local/bin` |
| `omarchy-osd` | stub: `omarchy-shell -q osd show`, no-op fallback | `~/.local/bin` |
| `omarchy-brightness-display` | stub: DDC/CI (`ddcutil`) instead of backlight/hyprctl | `~/.local/bin` |
| `omarchy-hyprland-monitor-scaling` | stub: `niri msg output <name> scale` | `~/.local/bin` |
| `xkbcli` | installed `libxkbcommon-tools` (real) | `/usr/bin/xkbcli` |
| `inotifywait` | installed `inotify-tools` (real) | `/usr/bin/inotifywait` |
| `ddcutil` / `brightnessctl` | installed for the brightness port | `/usr/bin` |

`omarchy-hook` (in `omarchy-bin/`) is a real port of upstream's hook dispatcher.

## Result

With these in place the shell's missing-binary warnings dropped from **116** to
**4** (the remaining 4 are `omarchy-agent-usage-update` /
`omarchy-update-available`, update-checkers outside this port's scope).

## QML call-site ports

Some helpers are called from QML, not the shell — those call sites were ported
instead of stubbed:

- `Commons/Style.qml` — `hyprctl -j getoption …` reads replaced by niri/no-op stubs; token defaults kept.
- `plugins/services/nightlight/Service.qml` — `hyprctl hyprsunset …` replaced by a state file.
- `plugins/panels/monitor/Panel.qml` — `hyprctl keyword monitor …` → `niri msg output … off/on`.
- `plugins/reminders/ReminderFlow.qml` — `$OMARCHY_PATH/bin/…` → PATH lookup.
