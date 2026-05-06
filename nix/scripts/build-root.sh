#!/bin/sh

openclaw_build_root_file() {
  if [ -n "${OPENCLAW_BUILD_ROOT_FILE:-}" ]; then
    printf '%s\n' "$OPENCLAW_BUILD_ROOT_FILE"
    return
  fi

  if [ -n "${NIX_BUILD_TOP:-}" ]; then
    printf '%s\n' "$NIX_BUILD_TOP/.openclaw-build-root"
    return
  fi

  printf '%s\n' "$PWD/.openclaw-build-root"
}

openclaw_init_output_build_root() {
  if [ -z "${out:-}" ]; then
    return
  fi

  build_root="$out/.openclaw-build"
  build_root_file="$(openclaw_build_root_file)"

  rm -rf "$build_root"
  mkdir -p "$build_root"
  ( tar -cf - . ) | ( cd "$build_root" && tar -xf - )
  chmod -R u+w "$build_root"
  printf '%s\n' "$build_root" > "$build_root_file"
  cd "$build_root"
}

openclaw_enter_build_root() {
  build_root_file="$(openclaw_build_root_file)"
  if [ ! -f "$build_root_file" ]; then
    return
  fi

  build_root="$(cat "$build_root_file")"
  if [ -n "$build_root" ] && [ -d "$build_root" ]; then
    cd "$build_root"
  fi
}

openclaw_cleanup_output_pnpm_store() {
  build_root_file="$(openclaw_build_root_file)"
  build_root=""
  store_path=""

  if [ -f "$build_root_file" ]; then
    build_root="$(cat "$build_root_file")"
  fi

  if [ -n "$build_root" ] && [ -f "$build_root/${PNPM_STORE_PATH_FILE:-.pnpm-store-path}" ]; then
    store_path="$(cat "$build_root/${PNPM_STORE_PATH_FILE:-.pnpm-store-path}")"
  fi

  cd "${NIX_BUILD_TOP:-/tmp}" 2>/dev/null || cd / || true

  case "$store_path" in
    "$out"/*) rm -rf "$store_path" ;;
  esac
}

openclaw_cleanup_output_build_root() {
  build_root_file="$(openclaw_build_root_file)"
  build_root=""

  if [ -f "$build_root_file" ]; then
    build_root="$(cat "$build_root_file")"
  fi

  openclaw_cleanup_output_pnpm_store

  case "$build_root" in
    "$out"/*)
      if [ -n "${NIX_BUILD_TOP:-}" ] && [ -d "$NIX_BUILD_TOP" ]; then
        discard="$NIX_BUILD_TOP/.openclaw-build-root-discard-$$"
        if mv "$build_root" "$discard" 2>/dev/null; then
          return 0
        fi
      fi
      rm -rf "$build_root"
      ;;
  esac
}
