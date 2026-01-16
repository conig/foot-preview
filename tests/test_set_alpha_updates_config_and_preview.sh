#!/bin/sh
set -eu

. "$(dirname -- "$0")/lib/common.sh"
. "$(dirname -- "$0")/lib/assert.sh"

setup_env

write_theme "alpha.ini" "[colors]" "background=#445566" "foreground=#112233"
write_config "[main]" "include=themes/alpha.ini" "" "[colors]" "foreground=#112233"

capture_tty="$TEST_ROOT/tty-capture"
use_preview_tty "$capture_tty"

"$SCRIPT" --set-alpha 50

assert_file_contains "$FOOT_CONFIG" "alpha=0.500"

esc=$(printf '\033')
st="${esc}\\"
assert_file_contains "$capture_tty" "${esc}]11;rgba:44/55/66/80${st}"
