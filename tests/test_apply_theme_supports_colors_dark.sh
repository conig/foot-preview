#!/bin/sh
set -eu

. "$(dirname -- "$0")/lib/common.sh"
. "$(dirname -- "$0")/lib/assert.sh"

setup_env

# Common foot themes often ship dark/light sections instead of a plain [colors]
# section. Preview should still emit OSC updates for the preferred section.
write_theme "mode.ini" \
  "[colors-light]" \
  "foreground=#a1a2a3" \
  "background=#b1b2b3" \
  "[colors-dark]" \
  "foreground=#010203" \
  "background=#040506" \
  "selection-foreground=#070809" \
  "selection-background=#0a0b0c" \
  "cursor=#0d0e0f" \
  "regular0=#111111" \
  "bright7=#f0f0f0"

capture_tty="$TEST_ROOT/tty-capture"
use_preview_tty "$capture_tty"

set +e
"$SCRIPT" --apply "$FOOT_THEMES_DIR/mode.ini"
status=$?
set -e

assert_equals "0" "$status" "exit status mismatch: "

esc=$(printf '\033')
st="${esc}\\"

assert_file_contains "$capture_tty" "${esc}]10;#010203${st}"
assert_file_contains "$capture_tty" "${esc}]11;#040506${st}"
assert_file_contains "$capture_tty" "${esc}]19;#070809${st}"
assert_file_contains "$capture_tty" "${esc}]17;#0a0b0c${st}"
assert_file_contains "$capture_tty" "${esc}]12;#0d0e0f${st}"
assert_file_contains "$capture_tty" "${esc}]4;0;#111111${st}"
assert_file_contains "$capture_tty" "${esc}]4;15;#f0f0f0${st}"
assert_file_not_contains "$capture_tty" "${esc}]10;#a1a2a3${st}"
