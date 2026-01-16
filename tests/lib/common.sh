#!/bin/sh
set -eu

ROOT=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/foot-preview.sh"

mktemp_dir() {
  mktemp -d "${TMPDIR:-/tmp}/foot-preview-test.XXXXXX"
}

setup_env() {
  TEST_ROOT=$(mktemp_dir)
  HOME="$TEST_ROOT/home"
  XDG_CONFIG_HOME="$HOME/.config"
  mkdir -p "$XDG_CONFIG_HOME/foot/themes"
  FOOT_THEMES_DIR="$XDG_CONFIG_HOME/foot/themes"
  FOOT_CONFIG="$XDG_CONFIG_HOME/foot/foot.ini"
  PATH="$ROOT/tests/bin:$PATH"
  export TEST_ROOT HOME XDG_CONFIG_HOME FOOT_THEMES_DIR FOOT_CONFIG PATH
  unset FOOT_PREVIEW_TTYS
  unset FOOT_PREVIEW_SKIP_TTY
}

write_theme() {
  name=$1
  shift
  path="$FOOT_THEMES_DIR/$name"
  printf '%s\n' "$@" > "$path"
}

write_config() {
  printf '%s\n' "$@" > "$FOOT_CONFIG"
}

make_tty() {
  tty_path=$1
  mkdir -p "$(dirname -- "$tty_path")"
  : > "$tty_path"
}

use_preview_ttys() {
  ttys=$1
  FOOT_PREVIEW_TTYS="$ttys"
  export FOOT_PREVIEW_TTYS
}

use_preview_tty() {
  tty_path=$1
  make_tty "$tty_path"
  use_preview_ttys "$tty_path"
}

skip_real_tty() {
  FOOT_PREVIEW_SKIP_TTY=1
  export FOOT_PREVIEW_SKIP_TTY
}

setup_tmux_capture() {
  pane_tty=$1
  client_ttys=$2
  TMUX=1
  TMUX_PANE="pane-1"
  TMUX_PANE_TTY="$pane_tty"
  TMUX_CLIENT_TTYS="$client_ttys"
  export TMUX TMUX_PANE TMUX_PANE_TTY TMUX_CLIENT_TTYS
  make_tty "$pane_tty"
  old_ifs=$IFS
  IFS=:
  for tty in $client_ttys; do
    [ -n "$tty" ] || continue
    make_tty "$tty"
  done
  IFS=$old_ifs
}

setup_fzf_capture() {
  capture=$1
  args=$2
  export FZF_CAPTURE="$capture"
  export FZF_ARGS="$args"
  export FZF_SELECTION=""
  export FZF_EXIT_STATUS=0
}
