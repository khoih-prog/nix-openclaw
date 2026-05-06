#!/bin/sh
set -eu

if [ -z "${OPENCLAW_GATEWAY:-}" ]; then
  echo "OPENCLAW_GATEWAY is not set" >&2
  exit 1
fi

root="${OPENCLAW_GATEWAY}/lib/openclaw"

require_path() {
  if [ ! -e "$1" ]; then
    echo "Missing: $1" >&2
    exit 1
  fi
}

require_path "${root}/extensions"
require_path "${root}/extensions/memory-core"
require_path "${root}/extensions/memory-core/openclaw.plugin.json"
require_path "${root}/dist/extensions/memory-core/openclaw.plugin.json"
require_path "${root}/docs/reference/templates"
require_path "${root}/docs/reference/templates/AGENTS.md"
require_path "${root}/docs/reference/templates/SOUL.md"
require_path "${root}/docs/reference/templates/TOOLS.md"
require_path "${root}/skills"
require_path "${root}/node_modules/hasown"
require_path "${root}/node_modules/combined-stream"

require_js_alias_target() {
  alias="$1"
  alias_path="${root}/dist/${alias}"
  require_path "$alias_path"

  target="$(sed -n 's/^export \* from "\.\/\(.*\)";$/\1/p' "$alias_path" | head -1)"
  if [ -z "$target" ]; then
    echo "Alias has no export target: $alias_path" >&2
    exit 1
  fi
  require_path "${root}/dist/${target}"
}

require_js_alias_target "runtime-model-auth.runtime.js"

if ! find "${root}/skills" -name SKILL.md -type f | grep -q .; then
  echo "Missing bundled SKILL.md files under ${root}/skills" >&2
  exit 1
fi

echo "openclaw package contents: ok"
