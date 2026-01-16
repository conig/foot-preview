#!/bin/sh
set -eu

. "$(dirname -- "$0")/lib/common.sh"
. "$(dirname -- "$0")/lib/assert.sh"

setup_env

write_theme "tmux.ini" "[colors]" "foreground=#101112"

pane_tty="$TEST_ROOT/tty-pane"
client1="$TEST_ROOT/tty-client1"
client2="$TEST_ROOT/tty-client2"
setup_tmux_capture "$pane_tty" "$client1:$client2"
skip_real_tty

"$SCRIPT" --apply "$FOOT_THEMES_DIR/tmux.ini"

esc=$(printf '\033')
st="${esc}\\"
pattern="${esc}]10;#101112${st}"

assert_file_contains "$pane_tty" "$pattern"
assert_file_contains "$client1" "$pattern"
assert_file_contains "$client2" "$pattern"
