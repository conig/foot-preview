#!/bin/sh
set -eu

. "$(dirname -- "$0")/lib/common.sh"
. "$(dirname -- "$0")/lib/assert.sh"

setup_env

write_theme "original.ini" "[colors]" "foreground=#112233" "background=#445566" "selection-foreground=#778899" "selection-background=#aabbcc" "cursor=#ddeeff" "regular0=#000000" "bright7=#ffffff"
write_theme "other.ini" "[colors]" "foreground=#010203" "background=#040506"

write_config "[main]" "include=themes/original.ini"

capture_tty="$TEST_ROOT/tty-capture"
use_preview_tty "$capture_tty"

export FZF_EXIT_STATUS=130
export FZF_CAPTURE="$TEST_ROOT/fzf-input"
export FZF_ARGS="$TEST_ROOT/fzf-args"
export FZF_SELECTION=""

config_before="$TEST_ROOT/config.before"
cp "$FOOT_CONFIG" "$config_before"

set +e
"$SCRIPT"
status=$?
set -e

assert_equals "130" "$status" "exit status mismatch: "

if ! cmp "$config_before" "$FOOT_CONFIG" >/dev/null 2>&1; then
  fail "expected config to remain unchanged"
fi

esc=$(printf '\033')
st="${esc}\\"
assert_file_contains "$capture_tty" "${esc}]10;#112233${st}"
assert_file_contains "$capture_tty" "${esc}]11;#445566${st}"
