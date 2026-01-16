#!/bin/sh
set -eu

. "$(dirname -- "$0")/lib/common.sh"
. "$(dirname -- "$0")/lib/assert.sh"

setup_env

write_theme "old.ini" "[colors]" "foreground=#010203"
write_theme "new.ini" "[colors]" "foreground=#040506"

write_config "[main]" "include=themes/old.ini"

export FZF_CAPTURE="$TEST_ROOT/fzf-input"
export FZF_ARGS="$TEST_ROOT/fzf-args"
export FZF_SELECTION="$FOOT_THEMES_DIR/new.ini"
export FZF_EXIT_STATUS=0

"$SCRIPT"

relative=${FOOT_THEMES_DIR#"$HOME"/}
expected_include="include=~/$relative/new.ini"

assert_file_contains "$FOOT_CONFIG" "$expected_include"
assert_file_not_contains "$FOOT_CONFIG" "include=themes/old.ini"
