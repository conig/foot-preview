#!/bin/sh
set -eu

ROOT=$(cd -P -- "$(dirname -- "$0")/.." && pwd)
pass=0
fail=0

for test_file in "$ROOT"/tests/test_*.sh; do
  [ -e "$test_file" ] || continue
  if sh "$test_file"; then
    pass=$((pass + 1))
  else
    printf 'FAIL: %s\n' "$test_file" >&2
    fail=$((fail + 1))
  fi
done

printf 'Passed: %s, Failed: %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
