#!/usr/bin/env bash
# appinfo.sh — disk size + RAM lookups for Min Launcher.
#
# Usage:  appinfo.sh size <desktop-id>  ->  SIZE=<human>   (empty if unknown)
#         appinfo.sh ram                ->  "<desktop-id><TAB><human>" per running app
#         appinfo.sh dirs               ->  one visible top-level folder name of $HOME per line
#         appinfo.sh ls <dir>           ->  "<d|f><TAB><path>" for the direct children of <dir> (folders first)
#         appinfo.sh files <query> [dir] ->  "<d|f><TAB><path>" per match in $HOME (shallowest first)
#         appinfo.sh plugins            ->  "L<TAB><plugin list json>" + "M<TAB><manifest json>" per manifest
#         appinfo.sh pidram <pid>...    ->  "<pid><TAB><kB>" resident memory of each pid plus its child processes
#         appinfo.sh sys                ->  "USED=<kB> TOTAL=<kB>" system-wide memory

mode=${1:-}

human() {
  awk -v b="$1" 'BEGIN {
    split("B KB MB GB TB", u, " "); i = 1
    while (b >= 1024 && i < 5) { b /= 1024; i++ }
    if (i == 1 || b >= 100) printf "%d %s", b, u[i]
    else printf "%.1f %s", b, u[i]
  }'
}

# ====================== RAM per window (process trees) ========================
# Browsers and Electron apps spread over many processes, so each window's pid
# is summed together with all of its descendants.
if [ "$mode" = pidram ]; then
  shift
  [ "$#" -gt 0 ] || exit 0
  ps -e -o pid= -o ppid= -o rss= 2>/dev/null | awk -v want="$*" '
    { rss[$1] = $3; kids[$2] = kids[$2] " " $1 }
    function total(p,   n, a, i, t) {
      t = rss[p] + 0
      n = split(kids[p], a, " ")
      for (i = 1; i <= n; i++) if (a[i] != p) t += total(a[i])
      return t
    }
    END {
      n = split(want, w, " ")
      for (i = 1; i <= n; i++) if (w[i] ~ /^[0-9]+$/ && (w[i] in rss)) printf "%s\t%d\n", w[i], total(w[i])
    }'
  exit 0
fi

# ============================ RAM, whole system ===============================
if [ "$mode" = sys ]; then
  awk '/^MemTotal:/ { t = $2 } /^MemAvailable:/ { a = $2 }
       END { if (t > 0) printf "USED=%d TOTAL=%d\n", t - a, t }' /proc/meminfo 2>/dev/null
  exit 0
fi

# ============================ file search in $HOME ============================
# Directories passed in must live inside $HOME and contain no ".." parts.
home_dir_ok() {
  case "$1" in
    *..*) return 1 ;;
    "$HOME"|"$HOME"/*) [ -d "$1" ] ;;
    *) return 1 ;;
  esac
}

if [ "$mode" = dirs ]; then
  find -L "$HOME" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\n' 2>/dev/null | sort -f
  exit 0
fi

if [ "$mode" = ls ]; then
  dir=${2:-$HOME}
  home_dir_ok "$dir" || exit 0
  find -H "$dir" -mindepth 1 -maxdepth 1 ! -name '.*' -printf '%y\t%p\n' 2>/dev/null \
    | head -n 2000 \
    | awk -F'\t' '{ k = ($1 == "d") ? 0 : 1; print k "\t" tolower($2) "\t" $1 "\t" $2 }' \
    | sort -t "$(printf '\t')" -k1,1n -k2,2 \
    | head -n 300 \
    | cut -f3-
  exit 0
fi

if [ "$mode" = files ]; then
  q=${2:-}
  root_dir=${3:-$HOME}
  [ -n "${q// /}" ] || exit 0
  home_dir_ok "$root_dir" || exit 0
  # escape glob characters, then let spaces match anything in between
  q=$(printf '%s' "$q" | sed -e 's/[][\\?*]/\\&/g' -e 's/  */*/g')
  timeout 6 find -H "$root_dir" -xdev -mindepth 1 \
      \( -name '.*' -o -name node_modules -o -name __pycache__ -o -name target \) -prune -o \
      -iname "*${q}*" -printf '%y\t%p\n' 2>/dev/null \
    | head -n 5000 \
    | awk -F'\t' '{ d = gsub("/", "/", $2); print d "\t" $1 "\t" $2 }' \
    | sort -n -s -k1,1 \
    | head -n 100 \
    | cut -f2-
  exit 0
fi

# ============================ installed plugins ==============================
# Same sources the plugin manager uses: `omarchy plugin list --json` for the
# list and enabled state, plus each plugin's manifest for version/author/etc.
if [ "$mode" = plugins ]; then
  command -v omarchy >/dev/null 2>&1 || exit 0
  printf 'L\t'
  omarchy plugin list --json 2>/dev/null | tr -d '\n\r'
  printf '\n'
  for base in "${OMARCHY_PATH:-}/shell/plugins" "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins"; do
    [ -d "$base" ] || continue
    while IFS= read -r -d '' f; do
      printf 'M\t'
      head -c 65536 "$f" | tr -d '\n\r'
      printf '\n'
    done < <(find -L "$base" -maxdepth 4 -type f \( -name manifest.json -o -name '*.manifest.json' \) -print0 2>/dev/null)
  done
  exit 0
fi

# every applications/ dir that can hold .desktop files, highest priority first
adirs=()
for d in "${XDG_DATA_HOME:-$HOME/.local/share}" $(echo "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | tr ':' ' ') \
         /var/lib/flatpak/exports/share "$HOME/.local/share/flatpak/exports/share"; do
  [ -d "${d%/}/applications" ] && adirs+=("${d%/}/applications")
done

# =============================== RAM, all apps ================================
if [ "$mode" = ram ]; then
  tmp=$(mktemp -d) || exit 0
  trap 'rm -rf "$tmp"' EXIT

  ps -u "$(id -u)" -o pid= -o comm= -o args= > "$tmp/ps" 2>/dev/null
  # flatpak apps run in systemd scopes named app-flatpak-<id>-<n>.scope
  grep -H -o -E 'app-flatpak-[^/]*\.scope' /proc/[0-9]*/cgroup 2>/dev/null \
    | sed -E 's#^/proc/([0-9]+)/cgroup:app-flatpak-(.*)-[0-9]+\.scope$#\2 \1#' > "$tmp/fp"

  cat > "$tmp/prog.awk" <<'AWK'
function add(name, pid) { pids[name] = pids[name] " " pid }
function base(p,   k, a) { k = split(p, a, "/"); return a[k] }
function idof(path,   i, pre, rel) {
  for (i = 1; i <= nd; i++) {
    pre = D[i] "/"
    if (index(path, pre) == 1) {
      rel = substr(path, length(pre) + 1); sub(/\.desktop$/, "", rel); gsub("/", "-", rel)
      return rel
    }
  }
  return ""
}
function flush(   id, n, i, t, b, exe, fid, list, L, m, p, out, u) {
  if (cur == "" || ex == "") return
  id = idof(cur)
  if (id == "" || (id in seen)) return
  seen[id] = 1
  n = split(ex, toks, " "); exe = ""; fid = ""
  for (i = 1; i <= n; i++) {
    t = toks[i]; gsub(/["']/, "", t)
    if (t ~ /^-/ || t ~ /=/ || t ~ /^%/) continue
    b = base(t)
    if (b in wrap) continue
    if (b == "flatpak") {
      for (m = i + 1; m <= n; m++) if (toks[m] == "run") break
      for (m = m + 1; m <= n; m++) if (toks[m] !~ /^-/) { fid = toks[m]; break }
      break
    }
    exe = t; break
  }
  if (exe != "" && (base(exe) in gen)) exe = ""
  if (exe == "" && fid == "") return
  list = ""
  if (fid != "") list = fp[fid]
  else {
    b = tolower(base(exe))
    list = pids[b] " " pids[substr(b, 1, 15)]
    if (wm != "") list = list " " pids[tolower(wm)]
  }
  m = split(list, L, " "); out = ""
  for (i = 1; i <= m; i++) {
    p = L[i]
    if (p == "" || (p in u)) continue
    u[p] = 1; out = out "," p
  }
  if (out != "") print id "\t" substr(out, 2)
}
BEGIN {
  nd = split(dirs, D, ":")
  split("env uwsm-app uwsm setsid nohup", W, " "); for (k in W) wrap[W[k]] = 1
  split("sh bash dash zsh fish python python3 perl ruby node java xdg-open gtk-launch", G, " "); for (k in G) gen[G[k]] = 1
}
FILENAME == psf {
  if ($1 == self || $1 == pp) next
  c = tolower($2); b = tolower(base($3))
  add(c, $1); if (b != c) add(b, $1)
  next
}
FILENAME == fpf { fp[$1] = fp[$1] " " $2; next }
{
  if (FILENAME != cur) { flush(); cur = FILENAME; grp = 0; ex = ""; wm = "" }
  if ($0 ~ /^\[/) { grp = ($0 == "[Desktop Entry]"); next }
  if (grp && ex == "" && index($0, "Exec=") == 1) ex = substr($0, 6)
  else if (grp && wm == "" && index($0, "StartupWMClass=") == 1) wm = substr($0, 16)
}
END { flush() }
AWK

  [ ${#adirs[@]} -gt 0 ] || exit 0
  mapfile -d '' -t dfiles < <(find "${adirs[@]}" -name '*.desktop' -print0 2>/dev/null)
  [ ${#dfiles[@]} -gt 0 ] || exit 0
  dirlist=$(IFS=:; echo "${adirs[*]}")

  while IFS=$'\t' read -r id plist; do
    files=(); IFS=, read -ra pa <<< "$plist"
    for p in "${pa[@]}"; do [ -r "/proc/$p/smaps_rollup" ] && files+=("/proc/$p/smaps_rollup"); done
    kb=0
    [ ${#files[@]} -gt 0 ] && kb=$(awk '/^Pss:/ { s += $2 } END { printf "%d", s }' "${files[@]}" 2>/dev/null)
    if [ "${kb:-0}" -le 0 ]; then
      files=()
      for p in "${pa[@]}"; do [ -r "/proc/$p/status" ] && files+=("/proc/$p/status"); done
      [ ${#files[@]} -gt 0 ] && kb=$(awk '/^VmRSS:/ { s += $2 } END { printf "%d", s }' "${files[@]}" 2>/dev/null)
    fi
    [ "${kb:-0}" -gt 0 ] && printf '%s\t%s\n' "$id" "$(human $((kb * 1024)))"
  done < <(awk -v dirs="$dirlist" -v psf="$tmp/ps" -v fpf="$tmp/fp" -v self="$$" -v pp="$PPID" \
             -f "$tmp/prog.awk" "$tmp/ps" "$tmp/fp" "${dfiles[@]}")
  exit 0
fi

# =============================== size, one app ================================
[ "$mode" = size ] || exit 0
did=${2%.desktop}
[ -n "$did" ] || exit 0

finish_empty() { echo "SIZE="; exit 0; }

file=""
for d in "${adirs[@]}"; do
  if [ -f "$d/$did.desktop" ]; then file="$d/$did.desktop"; break; fi
done
if [ -z "$file" ]; then
  for d in "${adirs[@]}"; do
    f=$(find "$d" -name "$did.desktop" -print -quit 2>/dev/null)
    if [ -n "$f" ]; then file=$f; break; fi
  done
fi
[ -n "$file" ] || finish_empty

execline=$(awk '/^\[/ { g = ($0 == "[Desktop Entry]") }
                g && index($0, "Exec=") == 1 { sub(/^[^=]*=/, ""); print; exit }' "$file")

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

case "${exe##*/}" in
  sh|bash|dash|zsh|fish|python|python3|perl|ruby|node|java|xdg-open|gtk-launch) exe="" ;;
esac
[ -n "$exe" ] || [ -n "$flatpak_id" ] || finish_empty

path=""; real=""
if [ -n "$exe" ]; then
  case "$exe" in /*) path=$exe ;; *) path=$(command -v -- "$exe" 2>/dev/null) ;; esac
  [ -n "$path" ] && real=$(readlink -f -- "$path" 2>/dev/null)
fi

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

sb=$(app_size_bytes)
case "$sb" in
  ''|*[!0-9]*) echo "SIZE=" ;;
  *) echo "SIZE=$(human "$sb")" ;;
esac
