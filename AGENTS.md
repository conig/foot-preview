# foot-preview

A small POSIX sh tool for previewing foot themes in a floating fzf picker.
It scans `~/.config/foot/themes`, shows each theme name in that theme's own
foreground color, live-applies the theme as you move the cursor, and persists
the selection back into `~/.config/foot/foot.ini` so the choice survives
restarts.

## How it works

- Theme list is built from files in `~/.config/foot/themes`.
- Each entry is colored by parsing `[colors]` and reading `foreground`
  (fallback to `regular4` or `regular7`).
- Hovering a theme triggers live preview via OSC color sequences written to
  `/dev/tty` (foreground, background, selection, cursor, and 16 ANSI colors).
- Pressing Enter persists the theme by updating the `include=` line in
  `~/.config/foot/foot.ini`.
- If the picker is aborted, the original theme is restored in the terminal
  without touching the config file.

## Usage

- Run: `./foot-preview`
- Live preview: move the cursor
- Persist: press Enter
- Abort: `Esc` restores the original theme

## Requirements

- `fzf`
- `foot` running in a terminal (the script writes OSC sequences to the current
  tty)

## Configuration

- `FOOT_THEMES_DIR`: override the themes directory
- `FOOT_CONFIG`: override the foot config path

## Notes

- The script updates an existing `include=` line that points to a theme under
  the themes directory. If none exists, it inserts one into the file.
- Theme preview does not require a foot server; it works in the current
  terminal via OSC color updates.
