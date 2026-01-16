#!/bin/sh
set -eu

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_equals() {
  expected=$1
  actual=$2
  label=${3-}
  if [ "$expected" != "$actual" ]; then
    fail "${label}expected '$expected', got '$actual'"
  fi
}

assert_file_exists() {
  file=$1
  if [ ! -e "$file" ]; then
    fail "expected file to exist: $file"
  fi
}

assert_file_contains() {
  file=$1
  pattern=$2
  assert_file_exists "$file"
  if ! LC_ALL=C grep -a -F -- "$pattern" "$file" >/dev/null 2>&1; then
    fail "expected $file to contain '$pattern'"
  fi
}

assert_file_not_contains() {
  file=$1
  pattern=$2
  if LC_ALL=C grep -a -F -- "$pattern" "$file" >/dev/null 2>&1; then
    fail "expected $file to not contain '$pattern'"
  fi
}
