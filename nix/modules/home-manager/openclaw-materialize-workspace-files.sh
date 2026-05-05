#!/bin/sh
set -eu

if [ "$#" -lt 3 ]; then
  echo "usage: openclaw-materialize-workspace-files <manifest> <source> <target>..." >&2
  exit 1
fi

manifest="$1"
shift

if [ $(( $# % 2 )) -ne 0 ]; then
  echo "openclaw-materialize-workspace-files requires source/target pairs" >&2
  exit 1
fi

manifest_dir="$(dirname "$manifest")"
mkdir -p "$manifest_dir"
old_manifest="$(mktemp)"
new_manifest="$(mktemp)"
trap 'rm -f "$old_manifest" "$new_manifest"' EXIT

if [ -f "$manifest" ]; then
  cp "$manifest" "$old_manifest"
fi

was_managed() {
  grep -Fx -- "$1" "$old_manifest" >/dev/null 2>&1
}

copy_path() {
  source="$1"
  target="$2"

  if [ -e "$target" ] && [ ! -L "$target" ] && ! was_managed "$target"; then
    echo "OpenClaw workspace path exists and is not managed by Nix: $target" >&2
    echo "Move it into programs.openclaw.documents or remove it before switching." >&2
    exit 1
  fi

  rm -rf "$target"
  mkdir -p "$(dirname "$target")"

  if [ -d "$source" ]; then
    cp -RL "$source" "$target"
  else
    cp -L "$source" "$target"
  fi

  printf '%s\n' "$target" >> "$new_manifest"
}

while [ "$#" -gt 0 ]; do
  copy_path "$1" "$2"
  shift 2
done

sort -u "$new_manifest" > "$manifest"
