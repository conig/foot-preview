# foot-preview

Preview foot themes in a small fzf picker and persist the selection back to
`foot.ini`. This project was fully built by codex.

<img src="examples/foot-preview.gif" alt="foot-preview demo" width="100%">

## What it does

- Lists themes from `~/.config/foot/themes`.
- Colors each theme name using that theme's own foreground color.
- Live-previews a theme as you move the cursor (including across tmux clients).
- Persists the selection by updating the `include=` line in
  `~/.config/foot/foot.ini`.
- Restores the original theme on abort without changing the config.

## Assumptions

- You are running inside foot (the preview uses OSC color sequences written to
  `/dev/tty`) or tmux clients that are running in foot.
- `fzf` and `foot` are installed.
- Themes are stored as individual files under `~/.config/foot/themes` and each
  theme has a `[colors]` section.

## Dependencies

- `foot`
- `fzf`

### Install

Arch:

```sh
sudo pacman -S foot fzf
```

Ubuntu:

```sh
sudo apt update
sudo apt install foot fzf
```

Fedora:

```sh
sudo dnf install foot fzf
```

## Usage

```sh
./foot-preview
```

- Move the cursor to preview a theme.
- Press Enter to persist the selection.
- Press Esc to exit without changes (the original theme is restored in the
  current terminal and tmux clients).

## Configuration

- `FOOT_THEMES_DIR`: override the themes directory (default:
  `~/.config/foot/themes`).
- `FOOT_CONFIG`: override the foot config path (default:
  `~/.config/foot/foot.ini`).
- `FOOT_PREVIEW_TTYS`: colon-delimited list of tty paths to target for preview
  output (overrides tmux/tty detection).
- `FOOT_PREVIEW_SKIP_TTY`: set to `1` to skip writing to `/dev/tty` during
  preview (useful for tests).

### Alpha helpers

```sh
./foot-preview --set-alpha 75
./foot-preview --add-alpha -10
```

Note: alpha changes are written to `foot.ini`, but foot itself must be restarted
for the new alpha to take effect.

## Tests

```sh
./tests/run.sh
```

Tests route OSC output to temporary files by setting `FOOT_PREVIEW_TTYS` or
`FOOT_PREVIEW_SKIP_TTY` to avoid touching the active terminal.

## Notes

- The script updates the existing `include=` line in `foot.ini` that points
  into the themes directory. If none exists, it inserts one.
- Preview changes are applied only to the current terminal session (or all
  attached tmux clients) until you press Enter.
