#!/usr/bin/env bash
# build-catalog.sh — regenerate the marketplace catalog (index.json + thumbs).
# run this from the themes repo before committing when you add or change a theme.
# needs: git, ffmpeg (webp), jq. the shell's Super+/ Marketplace tab reads the
# index.json this writes off raw.githubusercontent, so what's listed here is
# exactly what a user can download.
set -euo pipefail
cd "$(dirname "$0")"

REPO="AidanMercer/themes"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
THUMBS=".catalog/thumbs"
mkdir -p "$THUMBS"

# a theme's manifest is whatever git actually tracks under its dir — that
# auto-excludes gitignored stuff (stills, the >100MB moon/wallpaper2.mp4), so
# we never list a file that would 404 on raw.githubusercontent.
tracked() { git ls-files "$1/"; }

# bare-hex getter, same shape as theme-colors.sh; prepends # for the catalog
gethex() {
  local v=""; [ -f "$2" ] && v=$(grep -ioP "^\s*$1\s*=\s*[\"']?#\K[0-9a-fA-F]{6}" "$2" | head -1)
  [ -n "$v" ] && printf '#%s' "$v" || printf ''
}
getbool() { [ -f "$2" ] && grep -qiP "^\s*$1\s*=\s*true\b" "$2" && echo true || echo false; }
getstr()  { [ -f "$2" ] && grep -oP "^\s*$1\s*=\s*\"\K[^\"]*" "$2" | head -1 || true; }

theme_objs=()
for d in */; do
  name="${d%/}"
  case "$name" in .*|default) continue ;; esac
  cfg="$name/config.toml"

  # a theme has to ship at least one wallpaper to exist in the switcher
  mapfile -t files < <(tracked "$name")
  [ "${#files[@]}" -gt 0 ] || continue
  walls=(); for f in "${files[@]}"; do
    case "$f" in "$name"/wallpaper*.jpg|"$name"/wallpaper*.jpeg|"$name"/wallpaper*.png|"$name"/wallpaper*.webp|"$name"/wallpaper*.gif|"$name"/wallpaper*.mp4)
      case "$f" in *.still.png) ;; *) walls+=("$f") ;; esac ;;
    esac
  done
  [ "${#walls[@]}" -gt 0 ] || { echo "skip $name: no tracked wallpaper" >&2; continue; }
  IFS=$'\n' walls=($(sort -V <<<"${walls[*]}")); unset IFS

  # thumbnail from the first tracked variant → 480px jpeg. jpeg (not webp) so
  # Qt's Image can decode it with just the libqjpeg plugin that ships with
  # qt6-base — no qt6-imageformats dependency on the user's machine.
  src="${walls[0]}"
  ffmpeg -y -v error -i "$src" -frames:v 1 -vf "scale=480:-1" -q:v 3 \
    "$THUMBS/$name.jpg" </dev/null || { echo "thumb failed for $name" >&2; continue; }

  video=false; for w in "${walls[@]}"; do [ "${w##*.}" = mp4 ] && video=true && break; done

  # oversized/untracked wallpapers on disk but NOT publishable — list them honestly
  oversized=()
  for w in "$name"/wallpaper*.mp4; do
    [ -e "$w" ] || continue
    git ls-files --error-unmatch "$w" >/dev/null 2>&1 || oversized+=("$w")
  done

  # per-file objects + total bytes
  file_objs=(); total=0
  for f in "${files[@]}"; do
    case "$f" in *.still.png) continue ;; esac
    sz=$(stat -c%s "$f"); total=$((total + sz))
    file_objs+=("$(jq -n --arg p "$f" --argjson b "$sz" '{path:$p,bytes:$b}')")
  done

  accents=$(jq -n --arg a "$(gethex accent "$cfg")" --arg b "$(gethex accent2 "$cfg")" \
                  --arg c "$(gethex accent3 "$cfg")" '[$a,$b,$c]|map(select(.!=""))')
  files_json=$(printf '%s\n' "${file_objs[@]}" | jq -s '.')
  over_json=$(printf '%s\n' "${oversized[@]:-}" | jq -R '.' | jq -s 'map(select(.!=""))')

  # per-theme revision: the last commit touching this dir. installs stamp it
  # into .mkt-version; the marketplace shows "update" when they stop matching
  rev=$(git log -1 --format=%h -- "$name/" || true)

  theme_objs+=("$(jq -n \
    --arg name "$name" --arg tagline "$(getstr tagline "$cfg")" \
    --argjson accents "$accents" \
    --argjson cyber "$(getbool cyber "$cfg")" --argjson light "$(getbool light "$cfg")" \
    --argjson video "$video" --argjson variants "${#walls[@]}" \
    --arg thumb "$THUMBS/$name.jpg" --argjson bytes "$total" \
    --arg rev "$rev" \
    --argjson files "$files_json" --argjson oversizedOmitted "$over_json" \
    '{name:$name,tagline:$tagline,accents:$accents,cyber:$cyber,light:$light,
      video:$video,variants:$variants,thumb:$thumb,bytes:$bytes,rev:$rev,
      files:$files,oversizedOmitted:$oversizedOmitted}')")
  echo "cataloged $name (${#walls[@]} variant(s), $((total/1048576))MB)" >&2
done

printf '%s\n' "${theme_objs[@]}" | jq -s \
  --arg repo "$REPO" --arg branch "$BRANCH" --arg commit "$(git rev-parse --short HEAD)" \
  '{repo:$repo, branch:$branch, commit:$commit, themes:(.|sort_by(.name))}' > index.json

echo "wrote index.json ($(jq '.themes|length' index.json) themes) + $THUMBS/*.jpg" >&2
