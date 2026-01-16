#!/bin/sh
set -eu

. "$(dirname -- "$0")/lib/common.sh"
. "$(dirname -- "$0")/lib/assert.sh"

setup_env

write_theme "full.ini" \
  "[colors]" \
  "foreground=#010203" \
  "background=#040506" \
  "selection-foreground=#070809" \
  "selection-background=#0a0b0c" \
  "cursor=#0d0e0f" \
  "regular0=#111111" \
  "regular1=#222222" \
  "regular2=#333333" \
  "regular3=#444444" \
  "regular4=#555555" \
  "regular5=#666666" \
  "regular6=#777777" \
  "regular7=#888888" \
  "bright0=#999999" \
  "bright1=#aaaaaa" \
  "bright2=#bbbbbb" \
  "bright3=#cccccc" \
  "bright4=#dddddd" \
  "bright5=#eeeeee" \
  "bright6=#f0f0f0" \
  "bright7=#0f0f0f"

capture_tty="$TEST_ROOT/tty-capture"
use_preview_tty "$capture_tty"

"$SCRIPT" --apply "$FOOT_THEMES_DIR/full.ini"

esc=$(printf '\033')
st="${esc}\\"

assert_file_contains "$capture_tty" "${esc}]10;#010203${st}"
assert_file_contains "$capture_tty" "${esc}]11;#040506${st}"
assert_file_contains "$capture_tty" "${esc}]19;#070809${st}"
assert_file_contains "$capture_tty" "${esc}]17;#0a0b0c${st}"
assert_file_contains "$capture_tty" "${esc}]12;#0d0e0f${st}"

assert_file_contains "$capture_tty" "${esc}]4;0;#111111${st}"
assert_file_contains "$capture_tty" "${esc}]4;1;#222222${st}"
assert_file_contains "$capture_tty" "${esc}]4;2;#333333${st}"
assert_file_contains "$capture_tty" "${esc}]4;3;#444444${st}"
assert_file_contains "$capture_tty" "${esc}]4;4;#555555${st}"
assert_file_contains "$capture_tty" "${esc}]4;5;#666666${st}"
assert_file_contains "$capture_tty" "${esc}]4;6;#777777${st}"
assert_file_contains "$capture_tty" "${esc}]4;7;#888888${st}"
assert_file_contains "$capture_tty" "${esc}]4;8;#999999${st}"
assert_file_contains "$capture_tty" "${esc}]4;9;#aaaaaa${st}"
assert_file_contains "$capture_tty" "${esc}]4;10;#bbbbbb${st}"
assert_file_contains "$capture_tty" "${esc}]4;11;#cccccc${st}"
assert_file_contains "$capture_tty" "${esc}]4;12;#dddddd${st}"
assert_file_contains "$capture_tty" "${esc}]4;13;#eeeeee${st}"
assert_file_contains "$capture_tty" "${esc}]4;14;#f0f0f0${st}"
assert_file_contains "$capture_tty" "${esc}]4;15;#0f0f0f${st}"
