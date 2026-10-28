#!/usr/bin/env bash
# appinfo.sh — on-demand disk size + RAM lookup for one installed app (Min Launcher).
#
# Usage:  appinfo.sh <want_size 0|1> <desktop-id>
# Output: SIZE=<human>   (only when want_size=1; empty if it can't be determined)
#         RAM=<human>    (only when the app is currently running)

want_size=${1:-0}
did=${2%.desktop}
[ -n "$did" ] || exit 0

human() {
  awk -v b="$1" 'BEGIN {
    split("B KB MB GB TB", u, " "); i = 1
    while (b >= 1024 && i < 5) { b /= 1024; i++ }
    if (i == 1 || b >= 100) printf "%d %s", b, u[i]
    else printf "%.1f %s", b, u[i]
  }'
}

# ---- locate the .desktop file ------------------------------------------------
dirs=("${XDG_DATA_HOME:-$HOME/.local/share}")
IFS=: read -ra xdg <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
dirs+=("${xdg[@]}" /var/lib/flatpak/exports/share "$HOME/.local/share/flatpak/exports/share")

file=""
for d in "${dirs[@]}"; do
  if [ -f "$d/applications/$did.desktop" ]; then file="$d/applications/$did.desktop"; break; fi
done
if [ -z "$file" ]; then
  for d in "${dirs[@]}"; do
    [ -d "$d/applications" ] || continue
    f=$(find "$d/applications" -name "$did.desktop" -print -quit 2>/dev/null)
    if [ -n "$f" ]; then file=$f; break; fi
  done
fi

finish_empty() { [ "$want_size" = 1 ] && echo "SIZE="; exit 0; }
[ -n "$file" ] || finish_empty

read_key() {
  awk -v k="$1" '/^\[/ { g = ($0 == "[Desktop Entry]") }
                 g && index($0, k "=") == 1 { sub(/^[^=]*=/, ""); print; exit }' "$file"
}
execline=$(read_key Exec)
wmclass=$(read_key StartupWMClass)

# ---- work out the real executable (skip env/uwsm wrappers, handle flatpak) ---
read -ra toks <<< "$execline"
n=${#toks[@]}; i=0; exe=""; flatpak_id=""
while [ $i -lt $n ]; do
  t=${toks[$i]//\"/}; t=${t//\'/}
  case "$t" in
    -*|*=*|%*) i=$((i+1)); continue ;;
  esac
  case "${t##*/}" in
    env|uwsm-app|uwsm|setsid|nohup) i=$((i+1)); continue ;;
    flatpak)
      j=$((i+1))
      if [ "${toks[$j]}" = run ]; then
        j=$((j+1))
        while [ $j -lt $n ]; do
          case "${toks[$j]}" in
            -*) j=$((j+1)) ;;
            *)  flatpak_id=${toks[$j]}; break ;;
          esac
        done
      fi
      break ;;
    *) exe=$t; break ;;
  esac
done

exe_base=${exe##*/}
case "$exe_base" in   # too generic to attribute size / processes to
  sh|bash|dash|zsh|fish|python|python3|perl|ruby|node|java|xdg-open|gtk-launch) exe=""; exe_base="" ;;
esac
[ -n "$exe" ] || [ -n "$flatpak_id" ] || finish_empty

path=""; real=""
if [ -n "$exe" ]; then
  case "$exe" in /*) path=$exe ;; *) path=$(command -v -- "$exe" 2>/dev/null) ;; esac
  [ -n "$path" ] && real=$(readlink -f -- "$path" 2>/dev/null)
fi

# ---- disk size ---------------------------------------------------------------
app_size_bytes() {
  local b="" pkg="" s="" top=""
  if [ -n "$flatpak_id" ]; then
    for d in "/var/lib/flatpak/app/$flatpak_id" "$HOME/.local/share/flatpak/app/$flatpak_id"; do
      if [ -d "$d" ]; then b=$(du -sb "$d" 2>/dev/null | cut -f1); break; fi
    done
    echo "$b"; return
  fi
  [ -n "$real" ] || return

  if command -v pacman >/dev/null 2>&1; then
    pkg=$(pacman -Qqo "$path" 2>/dev/null | head -n1)
    [ -n "$pkg" ] || pkg=$(pacman -Qqo "$real" 2>/dev/null | head -n1)
    if [ -n "$pkg" ]; then
      s=$(pacman -Qi "$pkg" 2>/dev/null | awk -F' *: *' '/^Installed Size/ { print $2; exit }')
      b=$(echo "$s" | awk '{ m = 1; if ($2 ~ /^K/) m = 1024; else if ($2 ~ /^M/) m = 1048576; else if ($2 ~ /^G/) m = 1073741824; printf "%d", $1 * m }')
      if [ -n "$b" ] && [ "$b" != 0 ]; then echo "$b"; return; fi
    fi
  fi
  if command -v dpkg-query >/dev/null 2>&1; then
    pkg=$(dpkg -S "$real" 2>/dev/null | head -n1 | cut -d: -f1)
    if [ -n "$pkg" ]; then
      s=$(dpkg-query -W -f='${Installed-Size}' "$pkg" 2>/dev/null)
      if [ -n "$s" ]; then echo $((s * 1024)); return; fi
    fi
  fi
  if command -v rpm >/dev/null 2>&1; then
    s=$(rpm -qf --qf '%{SIZE}' "$real" 2>/dev/null)
    case "$s" in ''|*[!0-9]*) ;; *) echo "$s"; return ;; esac
  fi
  case "$real" in
    /opt/*)
      top=/opt/$(echo "$real" | cut -d/ -f3)
      b=$(du -sb "$top" 2>/dev/null | cut -f1)
      if [ -n "$b" ]; then echo "$b"; return; fi ;;
  esac
  stat -c %s "$real" 2>/dev/null
}

if [ "$want_size" = 1 ]; then
  sb=$(app_size_bytes)
  case "$sb" in
    ''|*[!0-9]*) echo "SIZE=" ;;
    *) echo "SIZE=$(human "$sb")" ;;
  esac
fi

# ---- RAM (PSS summed over every matching process of this user) ---------------
pids=$(ps -u "$(id -u)" -o pid= -o comm= -o args= 2>/dev/null | awk \
  -v self="$$" -v pp="$PPID" -v exe="$exe_base" -v cls="$wmclass" '
  BEGIN { e = tolower(exe); c = tolower(cls); e15 = substr(e, 1, 15) }
  {
    if ($1 == self || $1 == pp) next
    comm = tolower($2); k = split($3, parts, "/"); base = tolower(parts[k])
    if ((e != "" && (base == e || comm == e || comm == e15)) ||
        (c != "" && (comm == c || base == c))) print $1
  }')

if [ -n "$flatpak_id" ]; then
  fp=$(grep -l -- "flatpak-$flatpak_id" /proc/[0-9]*/cgroup 2>/dev/null | cut -d/ -f3)
  pids=$(printf '%s\n%s\n' "$pids" "$fp")
fi
pids=$(printf '%s\n' "$pids" | grep -E '^[0-9]+$' | grep -vx -e "$$" -e "$PPID" | sort -u)
[ -n "$pids" ] || exit 0

files=()
for p in $pids; do [ -r "/proc/$p/smaps_rollup" ] && files+=("/proc/$p/smaps_rollup"); done
kb=0
if [ ${#files[@]} -gt 0 ]; then
  kb=$(awk '/^Pss:/ { s += $2 } END { printf "%d", s }' "${files[@]}" 2>/dev/null)
fi
if [ "${kb:-0}" -le 0 ]; then
  files=()
  for p in $pids; do [ -r "/proc/$p/status" ] && files+=("/proc/$p/status"); done
  [ ${#files[@]} -gt 0 ] && kb=$(awk '/^VmRSS:/ { s += $2 } END { printf "%d", s }' "${files[@]}" 2>/dev/null)
fi
if [ "${kb:-0}" -gt 0 ]; then echo "RAM=$(human $((kb * 1024)))"; fi
