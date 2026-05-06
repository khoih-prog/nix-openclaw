# Gates

Use targeted checks while debugging, then run the full relevant gate before handoff.

## Required Checks

- `scripts/check-flake-lock-owners.sh`
- selector tests
- updater shell syntax
- workflow YAML parse
- `nix flake show --accept-flake-config`
- Linux CI aggregator
- Darwin CI aggregator when available
- `scripts/hm-activation-macos.sh` when a macOS runner is available

## CI Verification

After pushing maintainer fixes, verify the GitHub Actions run for the pushed commit.

Never say you will keep polling unless a blocking poll is already running. If reporting a poll, name the active run or local polling session.

If CI fails, inspect the failing run, classify the failure, fix what belongs to `nix-openclaw`, and rerun until green or until the exact external blocker is proven.
