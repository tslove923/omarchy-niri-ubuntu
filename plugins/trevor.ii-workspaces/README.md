# ii Workspaces (Omarchy bar-widget)

> **niri port:** this build reads the port's `Niri` singleton (niri `msg --json
event-stream`) instead of the Hyprland singleton, and dispatches
> `niri msg action focus-workspace` on click. Occupancy/icons derive from niri
> workspace `idx` + `active_window_id` (niri exposes no per-workspace toplevel
> list). Deployed on `ubuntuvm2` at
> `~/.config/omarchy/plugins/trevor.ii-workspaces/`.

Workspace indicator for the Omarchy shell bar, styled after the
[illogical-impulse](https://github.com/end-4/dots-hyprland) Quickshell config's
`Workspaces.qml`: an animated pill slides under the focused workspace,
occupied workspaces are drawn as a translucent capsule that joins with its
occupied neighbors instead of showing as separate rounded boxes, and an
occupied, unfocused slot shows its biggest window's app icon in place of the
number (the same "biggest window on the workspace" icon ii's Workspaces.qml
picks). Numbers stay in the bar's own font (no Nerd Font glyphs), so it
matches the rest of an Omarchy bar rather than importing ii's typography.

## Install

```sh
omarchy plugin add https://github.com/tslove923/omarchy-ii-workspaces --enable
omarchy-shell shell rescanPlugins
omarchy bar move trevor.ii-workspaces --section left
```

## Settings

| key            | default | meaning                                    |
|----------------|---------|----------------------------------------------|
| `shown`        | 10      | number of fixed workspace slots               |
| `showAppIcons` | true    | overlay the biggest window's app icon on occupied, unfocused slots |

## What it does

Pure display: reads Hyprland's live workspace/window state (via Quickshell's
`Hyprland` singleton) and the desktop-entry database (via `DesktopEntries`,
for app icons) to draw the bar widget, and issues `hyprctl dispatch
hl.dsp.focus(...)` when a slot is clicked. It makes no network requests,
writes no files, and stores no state or credentials anywhere -- everything
it shows is recomputed live from Hyprland on every workspace/focus change.

## Removing

```sh
omarchy plugin remove trevor.ii-workspaces
```

Nothing else to clean up: this plugin has no state, cache, credential,
systemd unit, or config-file footprint outside its own plugin directory.
