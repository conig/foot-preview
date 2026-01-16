#!/bin/sh
set -eu

. "$(dirname -- "$0")/lib/common.sh"
. "$(dirname -- "$0")/lib/assert.sh"

setup_env

write_theme "theme-foreground.ini" "[colors]" "foreground=#112233" "background=#445566"
write_theme "theme-regular4.ini" "[colors]" "regular4=#010203"
write_theme "theme-regular7.ini" "[colors]" "regular7=#aabbcc"
write_theme "theme-background.ini" "[colors]" "background=#0a0b0c"

capture="$TEST_ROOT/fzf-input"
args="$TEST_ROOT/fzf-args"
setup_fzf_capture "$capture" "$args"

"$SCRIPT"

esc=$(printf '\033')
tab=$(printf '\t')

assert_file_contains "$capture" "${esc}[38;2;17;34;51;48;2;68;85;102mtheme-foreground.ini${esc}[0m${tab}$FOOT_THEMES_DIR/theme-foreground.ini"
assert_file_contains "$capture" "${esc}[38;2;1;2;3mtheme-regular4.ini${esc}[0m${tab}$FOOT_THEMES_DIR/theme-regular4.ini"
assert_file_contains "$capture" "${esc}[38;2;170;187;204mtheme-regular7.ini${esc}[0m${tab}$FOOT_THEMES_DIR/theme-regular7.ini"
assert_file_contains "$capture" "${esc}[48;2;10;11;12mtheme-background.ini${esc}[0m${tab}$FOOT_THEMES_DIR/theme-background.ini"

assert_file_contains "$args" "focus:execute-silent("
assert_file_contains "$args" "--apply {2}"
assert_file_contains "$args" "--persist {2}"
