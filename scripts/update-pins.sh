#!/usr/bin/env bash
set -euo pipefail

if [[ "${GITHUB_ACTIONS:-}" != "true" ]]; then
  echo "This script is intended to run in GitHub Actions (see .github/workflows/yolo-update.yml). Refusing to run locally." >&2
  exit 1
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_file="$repo_root/nix/sources/openclaw-source.nix"
app_file="$repo_root/nix/packages/openclaw-app.nix"
config_options_file="$repo_root/nix/generated/openclaw-config-options.nix"

log() {
  printf '>> %s\n' "$*" >&2
}

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/update-pins.sh select
  scripts/update-pins.sh apply <release_tag> <release_sha> <app_url>
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required but not installed." >&2
    exit 1
  fi
}

current_field() {
  local file="$1"
  local key="$2"
  awk -F'"' -v key="$key" '$0 ~ key" =" { print $2; exit }' "$file"
}

resolve_release_tag_sha() {
  local tag="$1"
  local tag_refs
  tag_refs=$(git ls-remote https://github.com/openclaw/openclaw.git "refs/tags/${tag}" "refs/tags/${tag}^{}" || true)
  if [[ -z "$tag_refs" ]]; then
    echo ""
    return 0
  fi

  local deref_sha plain_sha
  deref_sha=$(printf '%s\n' "$tag_refs" | awk '/\^\{\}$/ { print $1; exit }')
  if [[ -n "$deref_sha" ]]; then
    printf '%s\n' "$deref_sha"
    return 0
  fi

  plain_sha=$(printf '%s\n' "$tag_refs" | awk '!/\^\{\}$/ { print $1; exit }')
  printf '%s\n' "$plain_sha"
}

prefetch_json() {
  local url="$1"
  nix --extra-experimental-features "nix-command flakes" store prefetch-file --unpack --json "$url"
}

prefetch_file_json() {
  local url="$1"
  nix --extra-experimental-features "nix-command flakes" store prefetch-file --json "$url"
}

unpacked_zip_hash() {
  local url="$1"
  local archive_prefetch archive_path unpack_dir app_list app_count app_path app_hash

  archive_prefetch=$(prefetch_file_json "$url")
  archive_path=$(printf '%s' "$archive_prefetch" | jq -r '.path // .storePath // empty')
  if [[ -z "$archive_path" || ! -f "$archive_path" ]]; then
    echo "Failed to prefetch app archive for $url" >&2
    return 1
  fi

  unpack_dir=$(mktemp -d)
  if ! unzip -q "$archive_path" -d "$unpack_dir"; then
    rm -rf "$unpack_dir"
    echo "Failed to unzip app archive: $archive_path" >&2
    return 1
  fi

  app_list=$(find "$unpack_dir" -maxdepth 3 -type d -name '*.app' -print)
  app_count=$(printf '%s\n' "$app_list" | sed '/^$/d' | wc -l | tr -d ' ')
  if [[ "$app_count" != "1" ]]; then
    rm -rf "$unpack_dir"
    echo "Expected exactly one .app in app archive; found $app_count" >&2
    return 1
  fi

  app_path=$(printf '%s\n' "$app_list" | sed -n '1p')
  if [[ ! -d "$app_path/Contents" ]]; then
    rm -rf "$unpack_dir"
    echo "App archive contains an invalid app bundle: $app_path" >&2
    return 1
  fi

  if ! app_hash=$(nix --extra-experimental-features "nix-command flakes" hash path "$unpack_dir"); then
    rm -rf "$unpack_dir"
    echo "Failed to hash unpacked app archive: $archive_path" >&2
    return 1
  fi
  rm -rf "$unpack_dir"
  printf '%s\n' "$app_hash"
}

refresh_pnpm_hash() {
  local build_log pnpm_hash
  build_log=$(mktemp)
  if ! nix build .#openclaw-gateway --accept-flake-config >"$build_log" 2>&1; then
    pnpm_hash=$(grep -Eo 'got: *sha256-[A-Za-z0-9+/=]+' "$build_log" | head -n 1 | sed 's/.*got: *//' || true)
    if [[ -z "$pnpm_hash" ]]; then
      tail -n 200 "$build_log" >&2 || true
      rm -f "$build_log"
      return 1
    fi
    log "pnpmDepsHash mismatch detected: $pnpm_hash"
    perl -0pi -e "s|pnpmDepsHash = \"[^\"]*\";|pnpmDepsHash = \"${pnpm_hash}\";|" "$source_file"
    nix build .#openclaw-gateway --accept-flake-config >"$build_log" 2>&1 || {
      tail -n 200 "$build_log" >&2 || true
      rm -f "$build_log"
      return 1
    }
  fi
  rm -f "$build_log"
}

regenerate_config_options() {
  local selected_sha="$1"
  local source_store_path="$2"
  local tmp_src
  tmp_src=$(mktemp -d)

  if [[ -d "$source_store_path" ]]; then
    cp -R "$source_store_path" "$tmp_src/src"
  elif [[ -f "$source_store_path" ]]; then
    mkdir -p "$tmp_src/src"
    tar -xf "$source_store_path" -C "$tmp_src/src" --strip-components=1
  else
    echo "Source path not found: $source_store_path" >&2
    rm -rf "$tmp_src"
    exit 1
  fi

  chmod -R u+w "$tmp_src/src"

  nix shell --extra-experimental-features "nix-command flakes" nixpkgs#nodejs_22 nixpkgs#pnpm_10 -c \
    bash -c "cd '$tmp_src/src' && pnpm install --frozen-lockfile --ignore-scripts"

  nix shell --extra-experimental-features "nix-command flakes" nixpkgs#nodejs_22 nixpkgs#pnpm_10 -c \
    bash -c "cd '$tmp_src/src' && OPENCLAW_SCHEMA_REV='${selected_sha}' pnpm exec tsx '$repo_root/nix/scripts/generate-config-options.ts' --repo . --out '$config_options_file'"

  rm -rf "$tmp_src"
}

select_release() {
  local release_json selection_json current_rev current_version release_tag app_url release_version selected_sha
  local latest_stable_tag skipped_releases has_update
  current_rev=$(current_field "$source_file" "rev")
  current_version=$(current_field "$app_file" "version")

  log "Fetching OpenClaw stable release metadata"
  release_json=$(gh api '/repos/openclaw/openclaw/releases?per_page=100')
  selection_json=$(printf '%s' "$release_json" | node "$repo_root/scripts/select-openclaw-release.mjs")

  latest_stable_tag=$(printf '%s' "$selection_json" | jq -r '.latestStable.tagName // empty')
  release_tag=$(printf '%s' "$selection_json" | jq -r '.latestFullPackageableStable.tagName // empty')
  release_version=$(printf '%s' "$selection_json" | jq -r '.latestFullPackageableStable.releaseVersion // empty')
  app_url=$(printf '%s' "$selection_json" | jq -r '.latestFullPackageableStable.appUrl // empty')
  skipped_releases=$(printf '%s' "$selection_json" | jq -r '[.skippedStableReleases[]?.tagName | select(. != null)] | join(",")')

  if [[ -z "$release_tag" || -z "$release_version" || -z "$app_url" ]]; then
    echo "Failed to resolve a full packageable OpenClaw stable release" >&2
    if [[ -n "$latest_stable_tag" ]]; then
      echo "Latest stable release: $latest_stable_tag" >&2
    fi
    if [[ -n "$skipped_releases" ]]; then
      echo "Skipped stable releases: $skipped_releases" >&2
    fi
    exit 1
  fi

  selected_sha=$(resolve_release_tag_sha "$release_tag")
  if [[ -z "$selected_sha" ]]; then
    echo "Failed to resolve tag SHA for $release_tag" >&2
    exit 1
  fi

  log "Selected full packageable stable release: $release_tag ($selected_sha)"
  if [[ -n "$skipped_releases" ]]; then
    log "Skipped newer stable releases without macOS zip assets: $skipped_releases"
  fi

  if [[ "$current_version" == "$release_version" && "$current_rev" == "$selected_sha" ]]; then
    has_update=false
  else
    has_update=true
  fi

  printf 'has_update=%s\n' "$has_update"
  printf 'release_tag=%s\n' "$release_tag"
  printf 'release_sha=%s\n' "$selected_sha"
  printf 'app_url=%s\n' "$app_url"
  printf 'release_version=%s\n' "$release_version"
  printf 'latest_stable_tag=%s\n' "$latest_stable_tag"
  printf 'skipped_releases=%s\n' "$skipped_releases"
}

apply_release() {
  local release_tag="$1"
  local selected_sha="$2"
  local app_url="$3"
  local release_version source_url source_prefetch source_hash source_store_path app_hash
  local backup_dir success

  release_version="${release_tag#v}"
  source_url="https://github.com/openclaw/openclaw/archive/${selected_sha}.tar.gz"

  source_prefetch=$(prefetch_json "$source_url")
  source_hash=$(printf '%s' "$source_prefetch" | jq -r '.hash // empty')
  source_store_path=$(printf '%s' "$source_prefetch" | jq -r '.path // .storePath // empty')
  if [[ -z "$source_hash" || -z "$source_store_path" ]]; then
    echo "Failed to resolve source hash/path for $selected_sha" >&2
    exit 1
  fi

  app_hash=$(unpacked_zip_hash "$app_url")
  if [[ -z "$app_hash" ]]; then
    echo "Failed to resolve app hash for $release_tag" >&2
    exit 1
  fi

  backup_dir=$(mktemp -d)
  success=0
  cp "$source_file" "$backup_dir/source.nix"
  cp "$app_file" "$backup_dir/app.nix"
  cp "$config_options_file" "$backup_dir/config-options.nix"

  cleanup_apply() {
    if [[ "$success" -ne 1 ]]; then
      cp "$backup_dir/source.nix" "$source_file"
      cp "$backup_dir/app.nix" "$app_file"
      cp "$backup_dir/config-options.nix" "$config_options_file"
    fi
    rm -rf "$backup_dir"
  }
  trap cleanup_apply RETURN

  perl -0pi -e 's|  releaseTag = "[^"]+";\n||g; s|  releaseVersion = "[^"]+";\n||g;' "$source_file"
  perl -0pi -e "s|rev = \"[^\"]+\";|releaseTag = \"${release_tag}\";\n  releaseVersion = \"${release_version}\";\n  rev = \"${selected_sha}\";|" "$source_file"
  perl -0pi -e "s|hash = \"[^\"]+\";|hash = \"${source_hash}\";|" "$source_file"
  perl -0pi -e 's|pnpmDepsHash = "[^"]*";|pnpmDepsHash = "";|' "$source_file"

  perl -0pi -e "s|version = \"[^\"]+\";|version = \"${release_version}\";|" "$app_file"
  perl -0pi -e "s|url = \"[^\"]+\";|url = \"${app_url}\";|" "$app_file"
  perl -0pi -e "s|hash = \"[^\"]+\";|hash = \"${app_hash}\";|" "$app_file"

  refresh_pnpm_hash
  regenerate_config_options "$selected_sha" "$source_store_path"

  success=1
}

mode="${1:-}"
case "$mode" in
  select)
    if [[ $# -ne 1 ]]; then
      usage
      exit 1
    fi
    require_cmd jq
    require_cmd gh
    require_cmd node
    select_release
    ;;
  apply)
    if [[ $# -ne 4 ]]; then
      usage
      exit 1
    fi
    require_cmd jq
    require_cmd nix
    require_cmd perl
    require_cmd unzip
    require_cmd find
    apply_release "$2" "$3" "$4"
    ;;
  *)
    usage
    exit 1
    ;;
esac
