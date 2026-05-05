#!/bin/sh
set -e

store_path_file="${PNPM_STORE_PATH_FILE:-.pnpm-store-path}"
if [ -f "$store_path_file" ]; then
  store_path="$(cat "$store_path_file")"
  export PNPM_STORE_DIR="$store_path"
  export PNPM_STORE_PATH="$store_path"
  export NPM_CONFIG_STORE_DIR="$store_path"
  export NPM_CONFIG_STORE_PATH="$store_path"
fi
export HOME="$(mktemp -d)"
export TMPDIR="${HOME}/tmp"
mkdir -p "$TMPDIR"
export OPENCLAW_LOG_DIR="${TMPDIR}/openclaw-logs"
mkdir -p "$OPENCLAW_LOG_DIR"
mkdir -p /tmp/openclaw || true
chmod 700 /tmp/openclaw || true
unset OPENCLAW_BUNDLED_PLUGINS_DIR
export VITEST_POOL="forks"
export VITEST_MIN_WORKERS="${VITEST_MIN_WORKERS:-1}"
export VITEST_MAX_WORKERS="${VITEST_MAX_WORKERS:-1}"
test_timeout="${OPENCLAW_GATEWAY_TEST_TIMEOUT:-60000}"
node_heap_mb="${OPENCLAW_GATEWAY_TEST_HEAP_MB:-4096}"
if [ -n "${NODE_OPTIONS:-}" ]; then
  export NODE_OPTIONS="$NODE_OPTIONS --max-old-space-size=$node_heap_mb"
else
  export NODE_OPTIONS="--max-old-space-size=$node_heap_mb"
fi

PATH="$PWD/node_modules/.bin:$PATH"

vitest_config="vitest.gateway.config.ts"
if [ ! -f "$vitest_config" ] && [ -f "test/vitest/vitest.gateway.config.ts" ]; then
  vitest_config="test/vitest/vitest.gateway.config.ts"
fi

vitest_cli="$PWD/node_modules/vitest/vitest.mjs"
if [ ! -f "$vitest_cli" ]; then
  vitest_cli="$(find "$PWD/node_modules" -path '*/vitest/vitest.mjs' -type f | head -n 1)"
fi

if [ -z "${vitest_cli:-}" ] || [ ! -f "$vitest_cli" ]; then
  echo "vitest CLI not found under $PWD/node_modules" >&2
  exit 1
fi

exec node "$vitest_cli" run \
  --config "$vitest_config" \
  --pool=forks \
  --testTimeout="$test_timeout"
