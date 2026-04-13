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

is_integer() {
  val=$1
  case $val in
    ''|-) return 1 ;;
    -*) val=${val#-} ;;
  esac
  case $val in
    ''|*[!0-9]*) return 1 ;;
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
  section=$(preferred_colors_section "$1")
  [ -n "$section" ] || return 0
  awk '
    function trim(s){sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s}
    BEGIN { in_colors=0; regular4=""; regular7=""; }
    /^[ \t]*\[/ {
      section_name=$0
      sub(/^[ \t]*\[/, "", section_name)
      sub(/\][ \t]*$/, "", section_name)
      if (section_name==section) in_colors=1; else in_colors=0;
      next
    }
    in_colors==0 { next }
    /^[ \t]*#/ || /^[ \t]*$/ { next }
    {
      line=$0
      n = split(line, parts, "=")
      if (n < 2) next
      key=trim(parts[1])
      val=trim(substr(line, index(line, "=")+1))
      sub(/[ \t][;#].*$/, "", val)
      val=trim(val)
      if (key=="foreground") { print val; exit }
      if (key=="regular4" && regular4=="") regular4=val
      if (key=="regular7" && regular7=="") regular7=val
    }
    END {
      if (regular4!="") print regular4
      else if (regular7!="") print regular7
    }
  ' section="$section" "$1"
}

theme_background() {
  section=$(preferred_colors_section "$1")
  [ -n "$section" ] || return 0
  awk '
    function trim(s){sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s}
    BEGIN { in_colors=0; fallback=""; }
    /^[ \t]*\[/ {
      section_name=$0
      sub(/^[ \t]*\[/, "", section_name)
      sub(/\][ \t]*$/, "", section_name)
      if (section_name==section) in_colors=1; else in_colors=0;
      next
    }
    in_colors==0 { next }
    /^[ \t]*#/ || /^[ \t]*$/ { next }
    {
      line=$0
      n = split(line, parts, "=")
      if (n < 2) next
      key=trim(parts[1])
      val=trim(substr(line, index(line, "=")+1))
      sub(/[ \t][;#].*$/, "", val)
      val=trim(val)
      if (key=="background") { print val; exit }
      if (key=="regular0" && fallback=="") fallback=val
    }
    END { if (fallback!="") print fallback }
  ' section="$section" "$1"
}

preferred_colors_section() {
  awk '
    BEGIN { saw_colors=0; saw_dark=0; saw_light=0; }
    /^[ \t]*\[/ {
      if ($0 ~ /^[ \t]*\[colors\][ \t]*$/) saw_colors=1
      else if ($0 ~ /^[ \t]*\[colors-dark\][ \t]*$/) saw_dark=1
      else if ($0 ~ /^[ \t]*\[colors-light\][ \t]*$/) saw_light=1
    }
    END {
      if (saw_colors) print "colors"
      else if (saw_dark) print "colors-dark"
      else if (saw_light) print "colors-light"
    }
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
    fg_color=$(theme_color "$path" || true)
    bg_color=$(theme_background "$path" || true)
    fg_rgb=
    bg_rgb=
    if [ -n "$fg_color" ]; then
      fg_rgb=$(hex_to_rgb "$fg_color" 2>/dev/null || true)
    fi
    if [ -n "$bg_color" ]; then
      bg_rgb=$(hex_to_rgb "$bg_color" 2>/dev/null || true)
    fi
    if [ -n "$fg_rgb" ] && [ -n "$bg_rgb" ]; then
      printf '\033[38;2;%s;48;2;%sm%s\033[0m\t%s\n' "$fg_rgb" "$bg_rgb" "$name" "$path"
    elif [ -n "$fg_rgb" ]; then
      printf '\033[38;2;%sm%s\033[0m\t%s\n' "$fg_rgb" "$name" "$path"
    elif [ -n "$bg_rgb" ]; then
      printf '\033[48;2;%sm%s\033[0m\t%s\n' "$bg_rgb" "$name" "$path"
    else
      printf '%s\t%s\n' "$name" "$path"
    fi
  done
}

apply_theme() {
  theme_file=$1
  is_safe_value "$theme_file" || return 1
  [ -r "$theme_file" ] || return 1
  alpha_hex=$(config_alpha_hex || true)
  case $alpha_hex in
    ''|ff) alpha_hex= ;;
  esac
  ttys=$(list_target_ttys || true)
  if [ -z "$ttys" ]; then
    ttys="/dev/tty"
  fi
  applied=0
  old_ifs=$IFS
  IFS=$NL
  for tty in $ttys; do
    [ -n "$tty" ] || continue
    if apply_theme_to_tty "$theme_file" "$tty" "$alpha_hex"; then
      applied=1
    fi
  done
  IFS=$old_ifs
  [ "$applied" -eq 1 ] || return 1
}

list_target_ttys() {
  if [ -n "${FOOT_PREVIEW_TTYS-}" ]; then
    printf '%s\n' "$FOOT_PREVIEW_TTYS" | tr ':' '\n' | awk '
      NF && !seen[$0]++ { print }
    '
    return 0
  fi
  {
    if command -v tty >/dev/null 2>&1; then
      tty_path=$(tty 2>/dev/null || true)
      case $tty_path in
        /dev/*) printf '%s\n' "$tty_path" ;;
      esac
    fi
    printf '%s\n' "/dev/tty"
    if [ -n "${TMUX-}" ] && command -v tmux >/dev/null 2>&1; then
      if [ -n "${TMUX_PANE-}" ]; then
        tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null || true
      fi
      tmux list-clients -F '#{client_tty}' 2>/dev/null || true
    fi
  } | awk -v skip="${FOOT_PREVIEW_SKIP_TTY-}" '
    NF && !seen[$0]++ {
      if (skip && $0=="/dev/tty") next
      print
    }
  '
}

apply_theme_to_tty() {
  theme_file=$1
  tty=$2
  alpha_hex=${3-}
  section=$(preferred_colors_section "$theme_file")
  is_safe_value "$tty" || return 1
  [ -n "$section" ] || return 1
  [ -w "$tty" ] || return 1
  awk -v tty="$tty" -v alpha_hex="$alpha_hex" -v section="$section" '
    function trim(s){sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s}
    function normalize(c){
      gsub(/^#/, "", c)
      if (length(c) == 8) c = substr(c, 1, 6)
      if (length(c) != 6) return ""
      if (c ~ /[^0-9A-Fa-f]/) return ""
      return tolower(c)
    }
    function alpha_ok(){
      return alpha_hex ~ /^[0-9a-f][0-9a-f]$/
    }
    function rgba_spec(color){
      return "rgba:" substr(color,1,2) "/" substr(color,3,2) "/" substr(color,5,2) "/" alpha_hex
    }
    function emit(code, color){
      color = normalize(color)
      if (color == "") return
      printf "\033]%s;#%s\033\\", code, color > tty
      emitted=1
    }
    function emit_background(color){
      color = normalize(color)
      if (color == "") return
      if (alpha_ok()) {
        printf "\033]11;%s\033\\", rgba_spec(color) > tty
      } else {
        printf "\033]11;#%s\033\\", color > tty
      }
      emitted=1
      bg_emitted=1
    }
    function emit_palette(idx, color){
      color = normalize(color)
      if (color == "") return
      printf "\033]4;%d;#%s\033\\", idx, color > tty
      emitted=1
    }
    BEGIN { in_colors=0; emitted=0; bg_emitted=0; bg_fallback=""; }
    /^[ \t]*\[/ {
      section_name=$0
      sub(/^[ \t]*\[/, "", section_name)
      sub(/\][ \t]*$/, "", section_name)
      if (section_name==section) in_colors=1; else in_colors=0;
      next
    }
    in_colors==0 { next }
    /^[ \t]*#/ || /^[ \t]*$/ { next }
    {
      line=$0
      n = split(line, parts, "=")
      if (n < 2) next
      key=trim(parts[1])
      val=trim(substr(line, index(line, "=")+1))
      sub(/[ \t][;#].*$/, "", val)
      val=trim(val)

      if (key=="foreground") emit(10, val)
      else if (key=="background") emit_background(val)
      else if (key=="selection-foreground") emit(19, val)
      else if (key=="selection-background") emit(17, val)
      else if (key=="cursor" || key=="cursor-color") {
        n = split(val, vals, /[ \t]+/)
        if (n >= 2) emit(12, vals[2])
        else emit(12, vals[1])
      } else if (key ~ /^regular[0-7]$/) {
        idx = substr(key, 8)
        emit_palette(idx, val)
        if (key=="regular0" && bg_fallback=="") bg_fallback=val
      } else if (key ~ /^bright[0-7]$/) {
        idx = 8 + substr(key, 7)
        emit_palette(idx, val)
      }
    }
    END {
      if (!bg_emitted && bg_fallback != "") emit_background(bg_fallback)
      if (!emitted) exit 1
      close(tty)
    }
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
    /*) printf '%s' "$path" ;;
    *) printf '%s/%s' "$(dirname -- "$FOOT_INI")" "$path" ;;
  esac
}

config_colors_value() {
  key=$1
  [ -r "$FOOT_INI" ] || return 0
  awk -v key="$key" '
    function trim(s){sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s}
    BEGIN { in_colors=0; val=""; }
    /^[ \t]*\[/ {
      if ($0 ~ /^[ \t]*\[colors\]/) in_colors=1; else in_colors=0;
      next
    }
    in_colors==0 { next }
    /^[ \t]*#/ || /^[ \t]*$/ { next }
    {
      line=$0
      n = split(line, parts, "=")
      if (n < 2) next
      k=trim(parts[1])
      v=trim(substr(line, index(line, "=")+1))
      sub(/[ \t][;#].*$/, "", v)
      v=trim(v)
      if (k==key) val=v
    }
    END { if (val!="") print val }
  ' "$FOOT_INI"
}

config_alpha_hex() {
  alpha=$(config_colors_value alpha || true)
  [ -n "$alpha" ] || return 0
  awk -v val="$alpha" '
    BEGIN {
      gsub(/[ \t]+/, "", val)
      if (val=="" || val ~ /[^0-9.]/) exit
      a = val + 0
      if (a < 0) a = 0
      if (a > 1) a = 1
      printf "%02x", int(a * 255 + 0.5)
    }
  '
}

config_alpha_percent() {
  alpha=$(config_colors_value alpha || true)
  awk -v val="$alpha" '
    BEGIN {
      gsub(/[ \t]+/, "", val)
      if (val=="" || val ~ /[^0-9.]/) {
        print 100
        exit
      }
      a = val + 0
      if (a < 0) a = 0
      if (a > 1) a = 1
      printf "%d", int(a * 100 + 0.5)
    }
  '
}

alpha_from_percent() {
  pct=$1
  awk -v val="$pct" '
    BEGIN {
      if (val < 0) val = 0
      if (val > 100) val = 100
      printf "%.3f", val / 100
    }
  '
}

current_theme_from_config() {
  [ -r "$FOOT_INI" ] || return 0
  themes_dir=$(expand_path "$THEMES_DIR")
  conf_dir=$(dirname -- "$FOOT_INI")
  awk -v themes_dir="$themes_dir" -v home="$HOME" -v conf_dir="$conf_dir" '
    function trim(s){sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s}
    function expand(p){
      if (p ~ /^~\//) return home substr(p, 3)
      if (p ~ /^\//) return p
      return conf_dir "/" p
    }
    BEGIN { last=""; last_theme=""; }
    {
      line=$0
      sub(/[;#].*$/, "", line)
      line=trim(line)
      if (line == "") next
      if (line ~ /^include[ \t]*=/) {
        val=trim(substr(line, index(line, "=")+1))
        if (val == "") next
        last=val
        path=expand(val)
        if (index(path, themes_dir "/") == 1) last_theme=val
      }
    }
    END {
      if (last_theme != "") print last_theme
      else if (last != "") print last
    }
  ' "$FOOT_INI"
}

apply_preview() {
  theme_file=${1-}
  if [ -n "$theme_file" ]; then
    apply_theme "$theme_file" || return 1
    return 0
  fi
  theme=$(current_theme_from_config || true)
  if [ -n "$theme" ]; then
    theme=$(expand_path "$theme")
    if [ -r "$theme" ] && apply_theme "$theme"; then
      return 0
    fi
  fi
  if [ -r "$FOOT_INI" ]; then
    apply_theme "$FOOT_INI" || true
  fi
}

update_config_alpha() {
  alpha_value=$1
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
  if ! awk -v alpha="$alpha_value" '
    BEGIN { in_colors=0; saw_colors=0; wrote=0; }
    {
      line=$0
      if (line ~ /^[ \t]*\[[^]]+\][ \t]*$/) {
        if (in_colors && !wrote) {
          print "alpha=" alpha
          wrote=1
        }
        if (line ~ /^[ \t]*\[colors\][ \t]*$/) {
          in_colors=1
          saw_colors=1
        } else {
          in_colors=0
        }
        print line
        next
      }
      if (in_colors) {
        test=line
        sub(/[;#].*$/, "", test)
        if (test ~ /^[ \t]*alpha[ \t]*=/) {
          match(line, /^[ \t]*/)
          lead=substr(line, RSTART, RLENGTH)
          comment=""
          if (match(line, /[;#]/)) comment=substr(line, RSTART)
          print lead "alpha=" alpha comment
          wrote=1
          next
        }
      }
      print line
    }
    END {
      if (!saw_colors) {
        print ""
        print "[colors]"
        print "alpha=" alpha
      } else if (in_colors && !wrote) {
        print "alpha=" alpha
      }
    }
  ' "$FOOT_INI" > "$tmp"; then
    return 1
  fi
  mv -- "$tmp" "$FOOT_INI"
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
  foot-preview --add-alpha PERCENT
  foot-preview --set-alpha PERCENT
EOF
}

if [ "${1:-}" = "--apply" ]; then
  [ $# -eq 2 ] || { usage >&2; exit 1; }
  if ! is_safe_value "$2"; then
    printf 'Theme path contains unsupported characters.\n' >&2
    exit 1
  fi
  apply_preview "$2"
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

case ${1:-} in
  --add|--add-alpha) mode=add ;;
  --set|--set-alpha) mode=set ;;
  *) mode= ;;
esac

if [ -n "$mode" ]; then
  [ $# -eq 2 ] || { usage >&2; exit 1; }
  if ! is_integer "$2"; then
    printf 'Alpha must be an integer.\n' >&2
    exit 1
  fi
  if [ "$mode" = "set" ]; then
    if [ "$2" -lt 0 ] || [ "$2" -gt 100 ]; then
      printf 'Alpha must be between 0 and 100.\n' >&2
      exit 1
    fi
    alpha_percent=$2
  else
    current=$(config_alpha_percent || true)
    [ -n "$current" ] || current=100
    alpha_percent=$((current + $2))
    if [ "$alpha_percent" -lt 0 ]; then
      alpha_percent=0
    elif [ "$alpha_percent" -gt 100 ]; then
      alpha_percent=100
    fi
  fi
  alpha_value=$(alpha_from_percent "$alpha_percent")
  if ! update_config_alpha "$alpha_value"; then
    printf 'Failed to update foot config: %s\n' "$FOOT_INI" >&2
    exit 1
  fi
  apply_preview
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
  original_theme_expanded=$(expand_path "$original_theme")
fi

set +e
selection=$(
  build_list | fzf \
    --ansi \
    --color=hl:-1:underline,hl+:-1:underline \
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
    apply_preview "$original_theme_expanded" || true
  fi
  exit "$status"
fi

if [ -n "$selection" ]; then
  if ! is_safe_value "$selection"; then
    if [ -n "$original_theme_expanded" ] && [ -r "$original_theme_expanded" ]; then
      apply_preview "$original_theme_expanded" || true
    fi
    printf 'Selection contains unsupported characters.\n' >&2
    exit 1
  fi
  config_path=$(config_theme_path "$selection")
  update_config_theme "$config_path"
fi
