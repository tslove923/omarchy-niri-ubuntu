# ii Clock (Omarchy bar-widget)

Time / date / ISO work-week label for the Omarchy shell bar, styled after the
[illogical-impulse](https://github.com/end-4/dots-hyprland) Quickshell
config's `ClockWidget.qml` + `services/DateTime.qml`: `h:mm ap` time,
followed by `ddd, MM/dd • WWnn`, joined with bullets. No popup or calendar —
just the label, in the bar's own font. Defaults match `dots/illogical-impulse/config.json`'s `time` block from
[tslove923/dots-hyprland](https://github.com/tslove923/dots-hyprland).

The ISO week math (`IsoWeek.js`) is ported from Omarchy's own
`shell/plugins/panels/clock/Model.js` (`isoWeek`/`isoWeekLiteral`/`pad2`), so
the `WWnn` label is computed the same way the built-in clock's format ring
would.

## Install

```sh
omarchy plugin add https://github.com/tslove923/omarchy-ii-clock --enable
omarchy-shell shell rescanPlugins
omarchy bar move trevor.ii-clock --section center
```

## Settings

| key          | default        | meaning                              |
|--------------|----------------|---------------------------------------|
| `format`     | `h:mm ap`      | Qt time format string                 |
| `dateFormat` | `ddd, MM/dd`   | Qt date format string                 |
| `showDate`   | `true`         | show the date + ISO week alongside the time |
