#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: openclaw-materialize-workspace-files <state-manifest> <source-target-manifest>" >&2
  exit 1
fi

manifest="$1"
source_manifest="$2"

manifest_dir="$(dirname "$manifest")"
mkdir -p "$manifest_dir"
new_manifest="$(mktemp)"
trap 'rm -f "$new_manifest"' EXIT

copy_path() {
  source="$1"
  target="$2"

  if [ -e "$target" ] || [ -L "$target" ]; then
    chmod -R u+w "$target" 2>/dev/null || true
    rm -rf "$target"
  fi
  mkdir -p "$(dirname "$target")"

  if [ -d "$source" ]; then
    cp -RL "$source" "$target"
  else
    cp -L "$source" "$target"
  fi

  printf '%s\n' "$target" >> "$new_manifest"
}

while IFS="$(printf '\t')" read -r source target; do
  if [ -n "$source" ] && [ -n "$target" ]; then
    copy_path "$source" "$target"
  fi
done < "$source_manifest"

sort -u "$new_manifest" > "$manifest"
