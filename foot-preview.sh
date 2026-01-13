#!/bin/sh
set -eu

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/foot"
THEMES_DIR="${FOOT_THEMES_DIR:-$CONFIG_DIR/themes}"
FOOT_INI="${FOOT_CONFIG:-$CONFIG_DIR/foot.ini}"

SELF_DIR=$(cd -P -- "$(dirname -- "$0")" && pwd)
SELF="$SELF_DIR/$(basename -- "$0")"
SELF_QUOTED=
TAB=$(printf '\t')
NL=$(printf '\nX')
NL=${NL%X}
CR=$(printf '\r')

trim() {
  s=$1
  s=${s#"${s%%[![:space:]]*}"}
  s=${s%"${s##*[![:space:]]}"}
  printf '%s' "$s"
}

quote_sh() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

is_safe_value() {
  case $1 in
    *"$TAB"*|*"$NL"*|*"$CR"*) return 1 ;;
  esac
  return 0
}

hex_to_rgb() {
  hex=$1
  hex=${hex#\#}
  case ${#hex} in
    8) hex=${hex%??} ;;
    6) ;;
    *) return 1 ;;
  esac
  case $hex in
    *[!0-9a-fA-F]*) return 1 ;;
  esac
  r_hex=${hex%????}
  g_hex=${hex#??}
  g_hex=${g_hex%??}
  b_hex=${hex#????}
  printf '%d;%d;%d' "$((16#$r_hex))" "$((16#$g_hex))" "$((16#$b_hex))"
}

theme_color() {
  awk '
    function trim(s){sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s}
    BEGIN { in_colors=0; fallback=""; }
    /^[ \t]*\[/ {
      if ($0 ~ /^[ \t]*\[colors\]/) in_colors=1; else in_colors=0;
      next
    }
    in_colors==0 { next }
    /^[ \t]*#/ || /^[ \t]*$/ { next }
    {
      line=$0
      sub(/#.*/, "", line)
      split(line, parts, "=")
      if (length(parts) < 2) next
      key=trim(parts[1])
      val=trim(substr(line, index(line, "=")+1))
      if (key=="foreground") { print val; exit }
      if (key=="regular4" && fallback=="") fallback=val
      if (key=="regular7" && fallback=="") fallback=val
    }
    END { if (fallback!="") print fallback }
  ' "$1"
}

build_list() {
  find "$THEMES_DIR" -maxdepth 1 -type f | sort | while IFS= read -r path; do
    [ -f "$path" ] || continue
    if ! is_safe_value "$path"; then
      continue
    fi
    name=$(basename -- "$path")
    if ! is_safe_value "$name"; then
      continue
    fi
    color=$(theme_color "$path" || true)
    if [ -n "$color" ]; then
      if rgb=$(hex_to_rgb "$color" 2>/dev/null); then
        printf '\033[38;2;%sm%s\033[0m\t%s\n' "$rgb" "$name" "$path"
        continue
      fi
    fi
    printf '%s\t%s\n' "$name" "$path"
  done
}

apply_theme() {
  theme_file=$1
  is_safe_value "$theme_file" || return 1
  [ -r "$theme_file" ] || return 1
  ttys=$(list_target_ttys || true)
  if [ -z "$ttys" ]; then
    ttys="/dev/tty"
  fi
  old_ifs=$IFS
  IFS=$NL
  for tty in $ttys; do
    [ -n "$tty" ] || continue
    apply_theme_to_tty "$theme_file" "$tty" || true
  done
  IFS=$old_ifs
}

list_target_ttys() {
  if [ -n "${TMUX-}" ] && command -v tmux >/dev/null 2>&1; then
    {
      if [ -n "${TMUX_PANE-}" ]; then
        tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null || true
      fi
      tmux list-clients -F '#{client_tty}' 2>/dev/null || true
    } | awk '
      NF && !seen[$0]++ { print }
    '
  fi
}

apply_theme_to_tty() {
  theme_file=$1
  tty=$2
  is_safe_value "$tty" || return 1
  [ -w "$tty" ] || return 1
  awk -v tty="$tty" '
    function trim(s){sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s}
    function normalize(c){
      gsub(/^#/, "", c)
      if (length(c) == 8) c = substr(c, 1, 6)
      if (length(c) != 6) return ""
      if (c ~ /[^0-9A-Fa-f]/) return ""
      return tolower(c)
    }
    function emit(code, color){
      color = normalize(color)
      if (color == "") return
      printf "\033]%s;#%s\033\\", code, color > tty
    }
    function emit_palette(idx, color){
      color = normalize(color)
      if (color == "") return
      printf "\033]4;%d;#%s\033\\", idx, color > tty
    }
    BEGIN { in_colors=0; }
    /^[ \t]*\[/ {
      if ($0 ~ /^[ \t]*\[colors\]/) in_colors=1; else in_colors=0;
      next
    }
    in_colors==0 { next }
    /^[ \t]*#/ || /^[ \t]*$/ { next }
    {
      line=$0
      sub(/#.*/, "", line)
      split(line, parts, "=")
      if (length(parts) < 2) next
      key=trim(parts[1])
      val=trim(substr(line, index(line, "=")+1))

      if (key=="foreground") emit(10, val)
      else if (key=="background") emit(11, val)
      else if (key=="selection-foreground") emit(19, val)
      else if (key=="selection-background") emit(17, val)
      else if (key=="cursor" || key=="cursor-color") {
        n = split(val, vals, /[ \t]+/)
        if (n >= 2) emit(12, vals[2])
        else emit(12, vals[1])
      } else if (key ~ /^regular[0-7]$/) {
        idx = substr(key, 8)
        emit_palette(idx, val)
      } else if (key ~ /^bright[0-7]$/) {
        idx = 8 + substr(key, 7)
        emit_palette(idx, val)
      }
    }
    END { fflush(tty) }
  ' "$theme_file"
}

config_theme_path() {
  theme_path=$1
  case $theme_path in
    "$HOME"/*) printf '~/%s' "${theme_path#"$HOME"/}" ;;
    *) printf '%s' "$theme_path" ;;
  esac
}

expand_path() {
  path=$1
  case $path in
    ~/*) printf '%s/%s' "$HOME" "${path#~/}" ;;
    *) printf '%s' "$path" ;;
  esac
}

current_theme_from_config() {
  [ -r "$FOOT_INI" ] || return 0
  awk '
    function trim(s){sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s}
    /^[ \t]*include[ \t]*=/ {
      val=trim(substr($0, index($0, "=")+1))
      print val
    }
  ' "$FOOT_INI" | tail -n 1
}

update_config_theme() {
  theme_path=$1
  is_safe_value "$theme_path" || return 1
  [ -r "$FOOT_INI" ] || return 1
  if command -v mktemp >/dev/null 2>&1; then
    tmp=$(mktemp "${FOOT_INI}.tmp.XXXXXX") || return 1
  else
    tmp="${FOOT_INI}.tmp.$$"
    (
      umask 077
      set -C
      : > "$tmp"
    ) 2>/dev/null || return 1
  fi
  theme_include=0
  while IFS= read -r line; do
    trimmed=$(trim "$line")
    case $trimmed in
      \#*|';'*|'')
        ;;
      include=*)
        include_path=$(trim "${trimmed#include=}")
        include_path=$(expand_path "$include_path")
        case $include_path in
          "$THEMES_DIR"/*) theme_include=1; break ;;
        esac
        ;;
    esac
  done < "$FOOT_INI"

  updated=0
  while IFS= read -r line; do
    trimmed=$(trim "$line")
    case $trimmed in
      \#*|';'*|'')
        printf '%s\n' "$line" >> "$tmp"
        ;;
      include=*)
        include_path=$(trim "${trimmed#include=}")
        include_path=$(expand_path "$include_path")
        if [ "$theme_include" -eq 1 ]; then
          case $include_path in
            "$THEMES_DIR"/*)
              if [ "$updated" -eq 0 ]; then
                printf 'include=%s\n' "$theme_path" >> "$tmp"
                updated=1
              fi
              continue
              ;;
          esac
        fi
        if [ "$theme_include" -eq 0 ] && [ "$updated" -eq 0 ]; then
          printf 'include=%s\n' "$theme_path" >> "$tmp"
          updated=1
          continue
        fi
        printf '%s\n' "$line" >> "$tmp"
        ;;
      *)
        printf '%s\n' "$line" >> "$tmp"
        ;;
    esac
  done < "$FOOT_INI"
  if [ "$updated" -eq 0 ]; then
    printf '\n[main]\ninclude=%s\n' "$theme_path" >> "$tmp"
  fi
  mv -- "$tmp" "$FOOT_INI"
}

usage() {
  cat <<'EOF'
foot-preview: interactive theme picker for foot

Usage:
  foot-preview
  foot-preview --apply THEME_FILE
  foot-preview --persist THEME_FILE
EOF
}

if [ "${1:-}" = "--apply" ]; then
  [ $# -eq 2 ] || { usage >&2; exit 1; }
  if ! is_safe_value "$2"; then
    printf 'Theme path contains unsupported characters.\n' >&2
    exit 1
  fi
  apply_theme "$2"
  exit 0
fi

if [ "${1:-}" = "--persist" ]; then
  [ $# -eq 2 ] || { usage >&2; exit 1; }
  if ! is_safe_value "$2"; then
    printf 'Theme path contains unsupported characters.\n' >&2
    exit 1
  fi
  config_path=$(config_theme_path "$2")
  update_config_theme "$config_path"
  exit 0
fi

if [ ! -d "$THEMES_DIR" ]; then
  printf 'themes directory not found: %s\n' "$THEMES_DIR" >&2
  exit 1
fi

if ! command -v fzf >/dev/null 2>&1; then
  printf 'fzf is required but not installed.\n' >&2
  exit 1
fi

SELF_QUOTED=$(quote_sh "$SELF")

original_theme=$(current_theme_from_config || true)
original_theme_expanded=
if [ -n "$original_theme" ]; then
  case $original_theme in
    ~/*) original_theme_expanded="$HOME/${original_theme#~/}" ;;
    *) original_theme_expanded="$original_theme" ;;
  esac
fi

set +e
selection=$(
  build_list | fzf \
    --ansi \
    --delimiter="$TAB" \
    --with-nth=1 \
    --nth=1 \
    --accept-nth=2 \
    --height=40% \
    --layout=reverse \
    --prompt='Theme> ' \
    --bind="focus:execute-silent($SELF_QUOTED --apply {2}),enter:execute-silent($SELF_QUOTED --persist {2})+accept"
)
status=$?
set -e

if [ "$status" -ne 0 ]; then
  if [ -n "$original_theme_expanded" ] && [ -r "$original_theme_expanded" ]; then
    apply_theme "$original_theme_expanded" || true
  fi
  exit "$status"
fi

if [ -n "$selection" ]; then
  if ! is_safe_value "$selection"; then
    if [ -n "$original_theme_expanded" ] && [ -r "$original_theme_expanded" ]; then
      apply_theme "$original_theme_expanded" || true
    fi
    printf 'Selection contains unsupported characters.\n' >&2
    exit 1
  fi
  config_path=$(config_theme_path "$selection")
  update_config_theme "$config_path"
fi
