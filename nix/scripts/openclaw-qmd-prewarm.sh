#!/usr/bin/env bash
set -euo pipefail

qmd="${OPENCLAW_QMD_BIN:?OPENCLAW_QMD_BIN is required}"
tmp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_dir"
  "$qmd" collection remove openclaw-prewarm >/dev/null 2>&1 || true
}
trap cleanup EXIT

printf "%s\n\n%s\n" \
  "# OpenClaw QMD prewarm" \
  "This temporary document warms QMD model caches." \
  > "$tmp_dir/prewarm.md"

"$qmd" collection remove openclaw-prewarm >/dev/null 2>&1 || true
"$qmd" collection add "$tmp_dir" --name openclaw-prewarm >/dev/null
"$qmd" update >/dev/null
"$qmd" embed >/dev/null
"$qmd" query "OpenClaw QMD prewarm" -n 1 --json >/dev/null
