#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: scripts/ci-nix-build.sh <label> <nix-build-args...>" >&2
  exit 1
fi

label="$1"
shift

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
log_dir="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/nix-openclaw-ci-meter"
safe_label=$(printf '%s' "$label" | tr -c 'A-Za-z0-9_.-' '-')
log_path="$log_dir/${safe_label}.nix.log"
json_log_path="$log_dir/${safe_label}.nix.jsonl"
outputs_path="$log_dir/${safe_label}.outputs"

mkdir -p "$log_dir"
: > "$log_path"
: > "$json_log_path"
: > "$outputs_path"

build_args=("$@")
if [[ "${NIX_METER_JSON_LOG:-1}" != "0" ]]; then
  has_json_log_path=0
  for ((i = 0; i < ${#build_args[@]}; i += 1)); do
    if [[ "${build_args[$i]}" == "--option" && "${build_args[$((i + 1))]:-}" == "json-log-path" ]]; then
      has_json_log_path=1
    fi
  done
  if [[ "$has_json_log_path" -eq 0 ]]; then
    build_args+=("--option" "json-log-path" "$json_log_path")
  fi
fi
if [[ "${NIX_METER_CAPTURE_OUTPUTS:-${NIX_METER_PRINT_OUT_PATHS:-1}}" != "0" ]]; then
  has_print_out_paths=0
  has_json_output=0
  for arg in "${build_args[@]}"; do
    [[ "$arg" == "--print-out-paths" ]] && has_print_out_paths=1
    [[ "$arg" == "--json" ]] && has_json_output=1
  done
  if [[ "$has_print_out_paths" -eq 0 && "$has_json_output" -eq 0 ]]; then
    build_args+=("--json")
  fi
fi

start_epoch=$(date +%s)
echo "nix-meter: start label=$label log=$log_path json-log=$json_log_path"

set +e
env NIX_SHOW_STATS="${NIX_SHOW_STATS:-1}" nix build "${build_args[@]}" > >(tee "$outputs_path") 2> >(
  perl -MPOSIX=strftime -e '
    my $log_path = shift @ARGV;
    open my $log, ">>", $log_path or die "open $log_path: $!";
    while (my $line = <STDIN>) {
      chomp $line;
      print {$log} strftime("%Y-%m-%dT%H:%M:%SZ", gmtime), " ", $line, "\n";
      print STDERR $line, "\n";
      select($log); $| = 1;
      select(STDERR); $| = 1;
    }
  ' "$log_path"
)
status=$?
set -e

end_epoch=$(date +%s)
elapsed=$((end_epoch - start_epoch))
echo "nix-meter: end label=$label status=$status seconds=$elapsed"

"$repo_root/scripts/summarize-nix-build-log.mjs" \
  --label "$label" \
  --seconds "$elapsed" \
  "$log_path" || true

if [[ "${NIX_METER_JSON_LOG:-1}" != "0" && -s "$json_log_path" ]]; then
  "$repo_root/scripts/summarize-nix-build-log.mjs" \
    --label "$label-structured" \
    "$json_log_path" || true
fi

if [[ "$status" -eq 0 && "${NIX_METER_BUILD_CLOSURE:-1}" != "0" ]]; then
  "$repo_root/scripts/summarize-nix-build-closure.mjs" \
    --label "$label" \
    "$outputs_path" || true
fi

exit "$status"
